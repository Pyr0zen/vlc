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

// redesign: one rounded inner corner of the video frame (W3.7). The square item is filled with
// `color` outside the quarter circle of its own size centered on its bottom right corner, which
// rounds the top left corner of the video opening; the other corners are this item rotated.

layout(location = 0) in vec2 qt_TexCoord0;

layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;

  vec4 color;
};

void main()
{
    // signed distance to the circle in item units (the radius is 1), positive outside
    float d = length(vec2(1.0) - qt_TexCoord0) - 1.0;

    // antialiased over one device pixel, like a Rectangle edge
    float coverage = clamp(0.5 + d / max(fwidth(d), 1e-6), 0.0, 1.0);

    // color is premultiplied
    fragColor = color * coverage * qt_Opacity;
}
