#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// **The eyebrows, moved** (the owner, 2026-10-16: "more eyebrow ...
/// expression like moving the eyebrows to emote"). A distortion over the
/// head's photograph: each brow is a soft ellipse, and the pixels inside it
/// are taken from a little lower down, so the brow and the skin round it rise
/// (or fall) together, fading to nothing at the edge. `left` and `right` are
/// each brow's middle and half size in points; `lifts` is the left brow's
/// lift and inner-end tilt, then the right's, in points (up is positive; a
/// positive tilt drops the inner end, a frown).
[[ stitchable ]] float2 browWarp(float2 position, float4 left, float4 right, float4 lifts) {
    float dy = 0.0;
    for (int i = 0; i < 2; i++) {
        float4 brow = i == 0 ? left : right;
        float lift = i == 0 ? lifts.x : lifts.z;
        float tilt = i == 0 ? lifts.y : lifts.w;
        float2 d = (position - brow.xy) / max(brow.zw, float2(0.001));
        float r2 = dot(d, d);
        if (r2 > 6.0) { continue; }
        float weight = exp(-r2 * 0.9);
        // The inner end is toward the nose: +x for the left brow on screen,
        // -x for the right.
        float inner = clamp(i == 0 ? d.x : -d.x, -1.2, 1.2);
        dy += (lift - tilt * inner) * weight;
    }
    return position + float2(0.0, dy);
}
