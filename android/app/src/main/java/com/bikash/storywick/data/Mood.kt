package com.bikash.storywick.data

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.graphics.vector.ImageVector

/** Background mood for a chapter. Mirrors iOS Audio/Mood.swift exactly — same
 *  25 names + None, same bed mapping, so the two apps sound identical. */
enum class Mood(val label: String, val icon: ImageVector, val track: String?) {
    NONE("None", Icons.Filled.VolumeOff, null),
    THRILLER("Thriller", Icons.Filled.Bolt, "thriller"),
    SUSPENSE("Suspense", Icons.Filled.RemoveRedEye, "suspense"),
    HORROR("Horror", Icons.Filled.TheaterComedy, "horror"),
    MYSTERY("Mystery", Icons.Filled.Search, "mystery"),
    FANTASY("Fantasy", Icons.Filled.AutoFixHigh, "fantasy"),
    ADVENTURE("Adventure", Icons.Filled.Map, "epic"),
    COMEDY("Comedy", Icons.Filled.SentimentSatisfied, "comedy"),
    ROMANCE("Romance", Icons.Filled.Favorite, "romance"),
    SAD("Emotional / Sad", Icons.Filled.WaterDrop, "sad"),
    INSPIRATIONAL("Inspirational", Icons.Filled.WbSunny, "inspirational"),
    CALM("Peaceful / Calm", Icons.Filled.Spa, "calm"),
    DRAMATIC("Dramatic", Icons.Filled.Movie, "epic"),
    EPIC("Epic", Icons.Filled.Terrain, "epic"),
    MAGICAL("Magical / Enchanted", Icons.Filled.AutoAwesome, "fantasy"),
    DARK_EERIE("Dark / Eerie", Icons.Filled.TheaterComedy, "horror"),
    SCI_FI("Sci-Fi / Futuristic", Icons.Filled.Adjust, "scifi"),
    ACTION("Action", Icons.Filled.Bolt, "thriller"),
    NOSTALGIC("Nostalgic", Icons.Filled.NightsStay, "dreamy"),
    DREAMY("Dreamy", Icons.Filled.NightsStay, "dreamy"),
    WHIMSICAL("Whimsical / Playful", Icons.Filled.SentimentSatisfied, "comedy"),
    FEEL_GOOD("Feel-Good / Happy", Icons.Filled.SentimentSatisfied, "comedy"),
    MELANCHOLIC("Melancholic", Icons.Filled.WaterDrop, "sad"),
    ATMOSPHERIC("Mysterious / Atmospheric", Icons.Filled.Search, "mystery"),
    CINEMATIC("Cinematic", Icons.Filled.Movie, "mystery"),
    MEDITATIVE("Meditative / Ambient", Icons.Filled.Spa, "meditative");

    companion object {
        fun from(raw: String?): Mood = entries.firstOrNull { it.name == raw } ?: MYSTERY
    }
}
