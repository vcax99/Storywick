package com.bikash.storywick.audio

/** The 11 Kokoro voices, in model speaker-id order — same list as iOS
 *  Audio/VoiceCatalog.swift's kokoroVoiceOptions. */
data class KokoroVoice(val id: Int, val voiceName: String, val gender: String, val accent: String)

val kokoroVoices = listOf(
    KokoroVoice(0, "Aria", "Female", "American"),
    KokoroVoice(1, "Bella", "Female", "American"),
    KokoroVoice(2, "Nicole", "Female", "American"),
    KokoroVoice(3, "Sarah", "Female", "American"),
    KokoroVoice(4, "Sky", "Female", "American"),
    KokoroVoice(5, "Adam", "Male", "American"),
    KokoroVoice(6, "Michael", "Male", "American"),
    KokoroVoice(7, "Emma", "Female", "British"),
    KokoroVoice(8, "Isabella", "Female", "British"),
    KokoroVoice(9, "George", "Male", "British"),
    KokoroVoice(10, "Lewis", "Male", "British"),
)

/** Default voice — Bella, same as iOS. */
const val DEFAULT_VOICE_ID = 1
