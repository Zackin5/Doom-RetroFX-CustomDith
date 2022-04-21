// RetroFX implementation
vec4 pixelate(sampler2D colorTex, float spread)
{
	ivec2 ssize = textureSize( InputTexture, 0 );
	
	float scalingOffset = 0.5 * altScaling;	// Calculate if alternative scaling offset should be used
	vec2 coord;
	if(scaleMode == 1 || scaleMode == 2)
		// Scale to resolution
		coord = (floor(TexCoord*mode2_res)+scalingOffset)/mode2_res;
	else
	{
		// Pixel scaling
		vec2 targtres = ssize / pixelcount;
		coord = (ceil(TexCoord*targtres)+scalingOffset)/targtres;
	}

	vec2 dcoord;
	dcoord = vec2( (TexCoord.x*ssize.x/pixelcount ) ,
				(TexCoord.y*ssize.y/pixelcount ) );
	ivec2 d_coord = ivec2( dcoord.x, dcoord.y );

	ivec2 dsize;
	if(noisePattern == 1)
		dsize = textureSize(BlueNoise, 0 );
	else
		dsize = textureSize(Bayer, 0 );

	d_coord.x -= int ( floor(float(d_coord.x/dsize.x)) )*dsize.x;
	d_coord.y -= int ( floor(float(d_coord.y/dsize.y)) )*dsize.y;

	float noiseTexel;
	if(noisePattern == 1)
		noiseTexel = texelFetch(BlueNoise, d_coord, 0 ).r;
	else
		noiseTexel = texelFetch(Bayer, d_coord, 0 ).r;

	float dth = 1.0+(0.5-noiseTexel)/(33.5-spread);

	return texture(colorTex, coord)*dth;
}

vec3 posterize_retrofx(vec3 pixelColor)
{
	vec3 c = pixelColor;
	c = pow(c, vec3(gamma));
	c = c * posterization;
	c = floor(c);
	c = c / posterization;
	c = pow(c, vec3(1.0/gamma));
	return c;
}

// Troocutter 24bit
float WeightedLum(vec3 colour)
{
	colour *= colour;
	colour.r *= 0.299;
	colour.g *= 0.587;
	colour.b *= 0.114;
	return sqrt(colour.r + colour.g + colour.b);
}

vec3 Tonemap(vec3 color, float sat)
{
	ivec3 c = ivec3(clamp(color, vec3(0.0), vec3(1.0)) * 255.0 + 0.5);
	int index = (c.r * 256 + c.g) * 256 + c.b;
	int tx = index % 4096;
	int ty = int(index * 0.000244140625);
	
	vec3 hueblend = texelFetch(TrooCullersLUT, ivec2(tx, ty), 0).rgb;
	vec3 colourblend = texelFetch(TrooCullersLUT, ivec2(tx, ty + 4096), 0).rgb;
	
	return mix(hueblend, colourblend, sat);
}

vec3 posterize_troo(vec3 pixelColor, float sat, float greyed)
{
	vec3 colour = pixelColor.rgb;
	vec3 blend = Tonemap(colour, sat);
	
	float maxRGB = max(blend.r, max(blend.g, blend.b));
	float minRGB = min(blend.r, min(blend.g, blend.b));
	
	if (maxRGB - minRGB == 0.0)
	{
		colour = colour * (1.0 - greyed) + (WeightedLum(colour) * greyed);
	}
	else
	{
		colour = blend / clamp(WeightedLum(blend), 0.000001, 1.0) * WeightedLum(colour);
	}

	return colour;
}

vec4 posterize(vec4 pixelColor)
{
	vec3 color = pixelColor.rgb;
	if (posterizationMode == 2)
		color = posterize_troo(color, 1.0, 1.0);
	else
		color = posterize_retrofx(color);

	return vec4(color, pixelColor.a);
}

void main() 
{
	if ( enablepixelate == 1 )
	{
		if ( posterizationMode > 0 )
		{
			vec4 c = pixelate(InputTexture, dspread);
			c = posterize(c);
			FragColor = vec4(c);
		}
		else
		{
			FragColor = pixelate(InputTexture, dspread);
		}
	}
	if ( enablepixelate == 0 )
	{
		vec4 c = texture(InputTexture, TexCoord.xy);
		c = posterize(c);
		FragColor = vec4(c);
	}
}