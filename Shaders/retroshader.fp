// MariFX\GZDDS Dither
#if __VERSION__ >= 130
	#define COMPAT_VARYING in
	#define COMPAT_TEXTURE texture
#else
	#define COMPAT_VARYING varying
	#define FragColor gl_FragColor
	#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
	#ifdef GL_FRAGMENT_PRECISION_HIGH
		precision highp float;
	#else
		precision mediump float;
	#endif
	#define COMPAT_PRECISION mediump
#else
	#define COMPAT_PRECISION
#endif

vec4 gzdds_dither(vec2 ssize, vec2 TexCoord)
{
	COMPAT_PRECISION float dither4[16] = float[]
	(
		0.0000, 0.5000, 0.1250, 0.6250,
		0.7500, 0.2500, 0.8750, 0.3750,
		0.1875, 0.6875, 0.0625, 0.5625,
		0.9375, 0.4375, 0.8125, 0.3125
	);
	float paldith = gzdds_dither_amount * 0.00390625;
	vec2 coord = TexCoord;
	vec2 targtres = ssize;
	vec2 sfact = vec2(textureSize(InputTexture,0));
	coord = vec2((floor(TexCoord.x*targtres.x)+0.5)/targtres.x,(floor(TexCoord.y*targtres.y)+0.5)/targtres.y);
	sfact.xy = targtres.xy;
	vec4 res = texture(InputTexture, coord);
	if ( res.r <= 0.0 ) res.r -= paldith;
	if ( res.g <= 0.0 ) res.g -= paldith;
	if ( res.b <= 0.0 ) res.b -= paldith;
	if ( res.r >= 1.0 ) res.r += paldith;
	if ( res.g >= 1.0 ) res.g += paldith;
	if ( res.b >= 1.0 ) res.b += paldith;
	res.rgb += paldith*dither4[int(coord.x*sfact.x)%4+int(coord.y*sfact.y)%4*4]-0.5*paldith;
	return res;
}

vec4 retrofx_dither(sampler2D colorTex, vec2 ssize, vec2 coord, float spread)
{
	vec2 dcoord;
	dcoord = vec2( (TexCoord.x*ssize.x/pixelcount ) ,
				(TexCoord.y*ssize.y/pixelcount ) );
	ivec2 d_coord = ivec2( dcoord.x, dcoord.y );

	ivec2 dsize;
	if(noisePattern == 2)
		dsize = textureSize(BlueNoise, 0 );
	else
		dsize = textureSize(Bayer, 0 );

	d_coord.x -= int ( floor(float(d_coord.x/dsize.x)) )*dsize.x;
	d_coord.y -= int ( floor(float(d_coord.y/dsize.y)) )*dsize.y;

	float noiseTexel;
	if(noisePattern == 2)
		noiseTexel = texelFetch(BlueNoise, d_coord, 0 ).r;
	else
		noiseTexel = texelFetch(Bayer, d_coord, 0 ).r;

	float dth = 1.0+(0.5-noiseTexel)/(33.5-spread);
	return texture(colorTex, coord)*dth;
}

// RetroFX implementation
vec4 pixelate(sampler2D colorTex, float spread)
{
	ivec2 ssize = textureSize( InputTexture, 0 );
	ivec2 mode2_res = ivec2(mode2_res_x, mode2_res_y);
	
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

	if(noisePattern == 1 || noisePattern == 2)
		return retrofx_dither(colorTex, ssize, coord, spread);
	if(noisePattern == 3)
		return gzdds_dither(ssize, coord);
		
	return texture(colorTex, coord);
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

vec3 posterize(vec3 color)
{
	if (posterizationMode == 2)
		color = posterize_troo(color, 1.0, 1.0);
	else if (posterizationMode == 3)
		color = posterize_softshade(color);
	else
		color = posterize_retrofx(color);

	return clamp(color, 0.0, 1.0);	// Saturate() color to prevent artifacts
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