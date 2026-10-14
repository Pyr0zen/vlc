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

// redesign: dashed outline of the Customize Player items (Figma: 1 px inside stroke, dashes
// [4, 4], video 19:12-19:28). Drawn the way Figma renders it: every edge starts and ends with a
// half dash at the corners (an L shape there) and the full dashes in between are spread evenly
// along the edge, so the gaps stretch a little and both ends of an edge look the same.
// All lengths are in device pixels (logical size x devicePixelRatio), so the line stays sharp
// at every Windows scaling.

layout(location = 0) in vec2 qt_TexCoord0;

layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;

  vec2 size;          // logical size of the item
  float dpr;          // device pixel ratio
  float lineWidth;    // logical
  float dash;         // logical dash length
  float gap;          // logical nominal gap length
  vec4 color;         // premultiplied
};

// part of the pixel [x - 0.5, x + 0.5] covered by the interval [lo, hi]
float cover(float x, float lo, float hi)
{
    return clamp(min(x + 0.5, hi) - max(x - 0.5, lo), 0.0, 1.0);
}

// coverage along an edge of length len at position t (device pixels)
float along(float t, float len)
{
    float d = dash * dpr;
    float corner = 0.5 * d;
    float g0 = gap * dpr;

    float inner = len - 2.0 * corner;
    float n = max(0.0, floor((inner - g0) / (d + g0) + 0.5));
    float g = (inner - n * d) / (n + 1.0);
    float period = d + g;

    float c = max(cover(t, 0.0, corner), cover(t, len - corner, len));

    if (n > 0.0) {
        float j = clamp(floor((t - corner - g) / period), 0.0, n - 1.0);
        float a = corner + g + j * period;
        c = max(c, cover(t, a, a + d));
        if (j + 1.0 < n)
            c = max(c, cover(t, a + period, a + period + d));
        if (j > 0.0)
            c = max(c, cover(t, a - period, a - period + d));
    }
    return c;
}

void main()
{
    vec2 s = size * dpr;
    vec2 p = qt_TexCoord0 * s;
    float lw = max(1.0, floor(lineWidth * dpr + 0.5));

    float top = cover(p.y, 0.0, lw) * along(p.x, s.x);
    float bottom = cover(p.y, s.y - lw, s.y) * along(p.x, s.x);
    float left = cover(p.x, 0.0, lw) * along(p.y, s.y);
    float right = cover(p.x, s.x - lw, s.x) * along(p.y, s.y);

    float coverage = max(max(top, bottom), max(left, right));

    fragColor = color * coverage * qt_Opacity;
}
