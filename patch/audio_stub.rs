//! Minimal no-audio backend for Miyoo Mini / Mini Plus MVP.
//! Replace wipi_core/src/platform/audio.rs with this file and remove
//! rodio + rustysynth from wipi_core/Cargo.toml.

use std::path::Path;

pub struct AudioEngine;

impl AudioEngine {
    pub fn new(_soundfont_path: Option<&Path>) -> Self {
        Self
    }

    pub fn set_volume(&self, _bgm_volume: f32, _sfx_volume: f32) {}

    pub fn sink(&self) -> AudioSink {
        AudioSink
    }
}

pub struct AudioSink;

impl wie_backend::AudioSink for AudioSink {
    fn play_wave(&self, _channel: u8, _sampling_rate: u32, _wave_data: &[i16]) {}

    fn midi_note_on(&self, _channel_id: u8, _note: u8, _velocity: u8) {}

    fn midi_note_off(&self, _channel_id: u8, _note: u8, _velocity: u8) {}

    fn midi_program_change(&self, _channel_id: u8, _program: u8) {}

    fn midi_control_change(&self, _channel_id: u8, _control: u8, _value: u8) {}

    fn midi_pitch_bend(&self, _channel_id: u8, _value: u16) {}

    fn midi_sysex(&self, _data: &[u8]) {}
}
