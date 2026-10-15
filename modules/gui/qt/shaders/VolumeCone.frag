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

// redesign: cone-shaped volume slider (video 3:04-3:10, 11:41; Figma "volume" component 244:184).
// A horizontal cone: a trapezoid 10 px tall on the left and full height on the right, with
// 3.5 px rounded corners (measured on the 2x export of "Rectangle 6", 89x28). The gradient part
// is the same shape inset by 1.5 px ("Group 14": 86x25 at 1.5,1.5, radius 2), so a 1.5 px
// `emptyColor` rim stays around it, and it is masked to the left of `level` (0..1 of the width).
// The green > orange > red gradient stays the same in every theme and accent (video
// 17:44-17:49), under the theme's `tint` (Figma: #000000 20 % in Dark, #FFFFFF 20 % in Light).
// The geometry scales with the height (Figma values at 28 px).

layout(location = 0) in vec2 qt_TexCoord0;

layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;

  vec2 size;
  float level;
  vec4 emptyColor;
  vec4 tint;
};

// signed distance (in px, negative inside) to an isosceles trapezoid centred on the origin:
// half-width r1 at y = -he, r2 at y = +he (Inigo Quilez, sdTrapezoid)
float sdTrapezoid(vec2 p, float r1, float r2, float he)
{
    vec2 k1 = vec2(r2, he);
    vec2 k2 = vec2(r2 - r1, 2.0 * he);
    p.x = abs(p.x);
    vec2 ca = vec2(p.x - min(p.x, (p.y < 0.0) ? r1 : r2), abs(p.y) - he);
    vec2 cb = p - k1 + k2 * clamp(dot(k1 - p, k2) / dot(k2, k2), 0.0, 1.0);
    float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
    return s * sqrt(min(dot(ca, ca), dot(cb, cb)));
}

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
    float k = size.y / 28.0;

    float r1 = 5.0 * k;            // half of the 10 px left end
    float r2 = size.y * 0.5;       // half of the full height on the right
    float corner = 3.5 * k;
    float rim = 1.5 * k;

    // the rounded trapezoid is the sharp one shrunk by `corner`, grown back by `corner`
    float slope = (r2 - r1) / w;
    float grow = corner * sqrt(1.0 + slope * slope);
    float he = w * 0.5 - corner;
    float d = sdTrapezoid(vec2(p.y - r2, p.x - w * 0.5),
                          r1 + slope * corner - grow,
                          r2 - slope * corner - grow,
                          he) - corner;

    float coverage = clamp(0.5 - d, 0.0, 1.0);
    float inner = clamp(0.5 - (d + rim), 0.0, 1.0);

    // filled part, antialiased at the level edge
    float filled = clamp(level * w - p.x + 0.5, 0.0, 1.0) * inner;
    // the colors are premultiplied: the tint lies over the gradient
    vec3 fill = gradientAt(clamp((p.x - rim) / (w - 2.0 * rim), 0.0, 1.0)) * (1.0 - tint.a) + tint.rgb;

    vec4 color = mix(emptyColor, vec4(fill, 1.0), filled);

    fragColor = color * coverage * qt_Opacity;
}
