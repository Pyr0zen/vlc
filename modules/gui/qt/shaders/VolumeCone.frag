#version 440

/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

// redesign: cone-shaped volume slider (video 3:04-3:10, 11:41; Figma "volume" component).
// A horizontal cone: rounded narrow tip on the left, full height on the right. The part left of
// `level` (0..1 of the width) shows the green > orange > red gradient, which stays the same in
// every theme and accent (video 17:44-17:49), under the theme's `tint` (Figma: #000000 20 % in
// Dark, #FFFFFF 20 % in Light); the rest shows `emptyColor`.

layout(location = 0) in vec2 qt_TexCoord0;

layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;

  vec2 size;
  float level;
  float tipRadius;
  vec4 emptyColor;
  vec4 tint;
};

vec3 gradientAt(float t)
{
    const vec3 c0 = vec3(0x95, 0xD3, 0x18) / 255.0;
    const vec3 c1 = vec3(0xB2, 0xA9, 0x18) / 255.0;
    const vec3 c2 = vec3(0xD3, 0x79, 0x18) / 255.0;
    const vec3 c3 = vec3(0xFF, 0x37, 0x37) / 255.0;
    const float p1 = 0.579;
    const float p2 = 0.792;

    if (t < p1)
        return mix(c0, c1, t / p1);
    if (t < p2)
        return mix(c1, c2, (t - p1) / (p2 - p1));
    return mix(c2, c3, (t - p2) / (1.0 - p2));
}

void main()
{
    vec2 p = qt_TexCoord0 * size;
    float w = size.x;
    float cy = size.y * 0.5;

    // signed distance (in px) to the cone outline, negative inside
    float d;
    if (p.x < tipRadius) {
        d = length(p - vec2(tipRadius, cy)) - tipRadius;
    } else {
        float slope = (cy - tipRadius) / max(1.0, w - tipRadius);
        float halfHeight = tipRadius + slope * (p.x - tipRadius);
        d = (abs(p.y - cy) - halfHeight) / sqrt(1.0 + slope * slope);
    }
    d = max(d, p.x - w);

    float coverage = clamp(0.5 - d, 0.0, 1.0);

    // filled part, antialiased at the level edge
    float filled = clamp(level * w - p.x + 0.5, 0.0, 1.0);
    // the colors are premultiplied: the tint lies over the gradient
    vec3 fill = gradientAt(clamp(p.x / w, 0.0, 1.0)) * (1.0 - tint.a) + tint.rgb;

    vec4 color = mix(emptyColor, vec4(fill, 1.0), filled);

    fragColor = color * coverage * qt_Opacity;
}
