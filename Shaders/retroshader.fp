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

void main() 
{
	if ( enablepixelate == 1 )
	{
		if ( enableposterization == 1 )
		{
			vec4 c = pixelate(InputTexture, dspread);
			c = pow(c, vec4(gamma, gamma, gamma, 1));
			c = c * posterization;
			c = floor(c);
			c = c / posterization;
			c = pow(c, vec4(1.0/gamma));
			FragColor = vec4(c);
		}
		if ( enableposterization == 0 )
		{
			FragColor = pixelate(InputTexture, dspread);
		}
	}
	if ( enablepixelate == 0 )
	{
		vec4 c = texture(InputTexture, TexCoord.xy);
		c = pow(c, vec4(gamma, gamma, gamma, 1));
		c = c * posterization;
		c = floor(c);
		c = c / posterization;
		c = pow(c, vec4(1.0/gamma));
		FragColor = vec4(c);
	}
}