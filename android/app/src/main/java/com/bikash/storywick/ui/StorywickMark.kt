package com.bikash.storywick.ui

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Fill
import com.bikash.storywick.ui.theme.BrandGreen
import com.bikash.storywick.ui.theme.BrandLime
import com.bikash.storywick.ui.theme.BrandTeal
import kotlin.math.PI
import kotlin.math.sin

/** Waveform bars flowing into a play triangle, lime -> green -> teal — the
 *  Compose sibling of iOS Support/StorywickMark.swift. Same 4 bar heights,
 *  same gentle wobble animation when [animated]. */
@Composable
fun StorywickMark(modifier: Modifier = Modifier, animated: Boolean = false) {
    val bars = remember { floatArrayOf(0.42f, 0.72f, 1.0f, 0.60f) }
    val t = if (animated) {
        val transition = rememberInfiniteTransition(label = "storywick-mark")
        transition.animateFloat(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(tween(2000, easing = LinearEasing), RepeatMode.Reverse),
            label = "wobble",
        ).value
    } else 0f

    Canvas(modifier) {
        val s = size.minDimension
        val gapFrac = 0.070f
        val barWidthFrac = 0.105f
        val triWidthFrac = 0.25f
        val triHeightFrac = 0.56f

        val totalWidthFrac = bars.size * barWidthFrac + (bars.size - 1) * gapFrac + 0.015f + triWidthFrac
        val startX = (size.width - totalWidthFrac * s) / 2f
        val centerY = size.height / 2f

        val brush = Brush.linearGradient(
            colors = listOf(BrandLime, BrandGreen, BrandTeal),
            start = Offset(0f, 0f),
            end = Offset(size.width, size.height),
        )

        var x = startX
        bars.forEachIndexed { i, base ->
            val wobble = 0.13f * sin(t * PI.toFloat() + i * 1.1f)
            val h = (base + wobble).coerceIn(0.3f, 1f) * s * 0.88f
            drawRoundRect(
                brush = brush,
                topLeft = Offset(x, centerY - h / 2f),
                size = Size(barWidthFrac * s, h),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(barWidthFrac * s / 2f),
            )
            x += (barWidthFrac + gapFrac) * s
        }
        x += 0.015f * s
        drawTriangle(brush, Offset(x, centerY), triWidthFrac * s, triHeightFrac * s)
    }
}

private fun DrawScope.drawTriangle(brush: Brush, leadingCenter: Offset, w: Float, h: Float) {
    val path = Path().apply {
        moveTo(leadingCenter.x, leadingCenter.y - h / 2f)
        lineTo(leadingCenter.x + w, leadingCenter.y)
        lineTo(leadingCenter.x, leadingCenter.y + h / 2f)
        close()
    }
    drawPath(path, brush = brush, style = Fill)
}

