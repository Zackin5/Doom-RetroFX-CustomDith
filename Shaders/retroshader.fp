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

// Trooculler 24bit
float WeightedLum(vec3 colour)
{
	colour *= colour;
	colour.r *= 0.299;
	colour.g *= 0.587;
	colour.b *= 0.114;
	return sqrt(colour.r + colour.g + colour.b);
}

vec3 Trooculler_Tonemap(vec3 color, float sat)
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
	vec3 colour = pixelColor;
	vec3 blend = Trooculler_Tonemap(colour, sat);
	
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

// SoftShade
vec3 rgb2hsv(vec3 c)
{
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = (c.g < c.b) ? vec4(c.bg, K.wz) : vec4(c.gb, K.xy);
	vec4 q = (c.r < p.x) ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0-K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

ivec2 getLUTCoordForRGB(vec3 fragcol)
{
    int b = int(clamp(fragcol.b * 63, 0, 63));
    ivec2 bluecoord = ivec2(b % 8, b / 8) * 64;
    ivec2 rgcoord = ivec2(
        int(clamp(fragcol.r * 63, 0, 63)),
        int(clamp(fragcol.g * 63, 0, 63)));

	return bluecoord + rgcoord;
}

vec3 posterize_softshade(vec3 color)
{
    vec3 fragcol = color;

	vec3 hsv = rgb2hsv(fragcol.rgb);
	hsv.y = clamp(hsv.y, 0.0, 1.0);
	hsv.z = max(hsv.z, 0.0);
	fragcol.rgb = hsv2rgb(hsv);

	return texelFetch(TexLUT8, getLUTCoordForRGB(fragcol), 0).rgb;
}

// GreyDoubt
float GreyDoubt_Tonemap( vec3 color )
{	ivec3 c; int index; int tx; int ty;

	c		= ivec3( clamp( color, 0.0, 1.0 ) * 255.0 + 0.5 );
	index	= ( c.r * 256 + c.g ) * 256 + c.b;
	tx		= index % 4096;
	ty		= index * 1 / 4096;
	
	return texelFetch( GDLUT, ivec2( tx, ty ), 0 ).x;
}

const vec3 grey = vec3( 0.2125862307855955516, 0.7151703037034108499, 0.07220049864333622685 );

vec3 posterize_greyDoubt(vec3 color)
{
	float greymap = GreyDoubt_Tonemap( color );
	return mix( color, vec3( dot( color, grey )), greymap );
}

vec3 posterize(vec3 color)
{
	if (greyDoubtMode == 1)
		color = posterize_greyDoubt(color);

	if (posterizationMode == 2)
		color = posterize_troo(color, 1.0, 1.0);
	else if (posterizationMode == 3)
		color = posterize_softshade(color);
	else
		color = posterize_retrofx(color);
	
	if (greyDoubtMode == 2)
		color = posterize_greyDoubt(color);

	return color;
}

void main() 
{
	if ( enablepixelate == 1 )
	{
		if ( posterizationMode > 0 )
		{
			vec4 c = pixelate(InputTexture, dspread);
			c.rgb = posterize(c.rgb);
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
		c.rgb = posterize(c.rgb);
		FragColor = vec4(c);
	}
}