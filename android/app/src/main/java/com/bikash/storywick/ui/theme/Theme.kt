package com.bikash.storywick.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color

/** The "Emerald" palette — same hex values as iOS Support/Theme.swift, so both
 *  apps are visually identical. Custom roles (spark, glow, highlight) don't map
 *  onto Material3's fixed slots, so this is a plain color bag via CompositionLocal
 *  rather than a MaterialTheme.colorScheme. */
data class StorywickColors(
    val background: Color,
    val backgroundLow: Color,
    val surface: Color,
    val surfaceRaised: Color,
    val stroke: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textFaint: Color,
    val accent: Color,
    val accentDeep: Color,
    val accentSoft: Color,
    val glow: Color,
    val spark: Color,
    val highlight: Color,
    val warning: Color,
    val danger: Color,
)

private val LightColors = StorywickColors(
    background = Color(0xFFF6F9F7),
    backgroundLow = Color(0xFFEDF3EF),
    surface = Color(0xFFFFFFFF),
    surfaceRaised = Color(0xFFFFFFFF),
    stroke = Color(0xFFE2E8E5),
    textPrimary = Color(0xFF111827),
    textSecondary = Color(0xFF64748B),
    textFaint = Color(0xFF94A3B8),
    accent = Color(0xFF059669),
    accentDeep = Color(0xFF047857),
    accentSoft = Color(0xFFE4F3EC),
    glow = Color(0xFF34D399),
    spark = Color(0xFF65A30D),
    highlight = Color(0xFFC7ECDA),
    warning = Color(0xFFD97706),
    danger = Color(0xFFDC2626),
)

private val DarkColors = StorywickColors(
    background = Color(0xFF0A0C0B),
    backgroundLow = Color(0xFF0E1512),
    surface = Color(0xFF141A18),
    surfaceRaised = Color(0xFF1B231F),
    stroke = Color(0xFF1F2937),
    textPrimary = Color(0xFFF8FAFC),
    textSecondary = Color(0xFF94A3B8),
    textFaint = Color(0xFF5A6B7A),
    accent = Color(0xFF10B981),
    accentDeep = Color(0xFF059669),
    accentSoft = Color(0xFF0E2A22),
    glow = Color(0xFF34D399),
    spark = Color(0xFFA3E635),
    highlight = Color(0xFF123329),
    warning = Color(0xFFF59E0B),
    danger = Color(0xFFF87171),
)

// The reader screen's emerald wash + card gradients — not part of the shared
// palette above (same split as iOS ReaderView's local groundGradient/cardGradient).
object ReaderPalette {
    val darkGroundTop = Color(0xFF0E1A16)
    val darkGround = Color(0xFF080C0B)
    val darkCard1 = Color(0xFF16291F)
    val darkCard2 = Color(0xFF0B1813)
    val lightGroundTop = Color(0xFFE9F5EF)
    val lightGround = Color(0xFFF8FBF9)
    val lightCard1 = Color(0xFFFFFFFF)
    val lightCard2 = Color(0xFFF1F8F4)
}

// Brand mark gradient — lime -> green -> teal, same stops as iOS StorywickMark.swift.
val BrandLime = Color(0xFFA3E635)
val BrandGreen = Color(0xFF10B981)
val BrandTeal = Color(0xFF06B6D4)

val LocalStorywickColors = compositionLocalOf { DarkColors }

@Composable
fun StorywickTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) DarkColors else LightColors
    CompositionLocalProvider(LocalStorywickColors provides colors) {
        MaterialTheme(content = content)
    }
}

/** Shorthand so screens can write `Theme.accent` etc., mirroring the iOS call sites. */
object Theme {
    val colors: StorywickColors
        @Composable get() = LocalStorywickColors.current
}
