// Copyright 2022 beekeeb
// SPDX-License-Identifier: GPL-2.0-or-later

#include QMK_KEYBOARD_H

/* Layers */
enum layers {
    SEMIMAK,
    QWERTY,
    GAMING,
    SYMBOLS,
    NAVIGATION,
    FUN
};

/* Combos */

/* Keymaps */
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    /* Base Layers */
    [SEMIMAK] = LAYOUT_split_3x6_3(
        KC_ESC,  KC_F,    KC_L,    KC_H,    KC_V,    KC_Z,                               KC_Q,    KC_W,    KC_U,    KC_O,    KC_Y,    KC_ESC,
        KC_LCTL, KC_S,    KC_R,    KC_N,    KC_T,    KC_K,                               KC_C,    KC_D,    KC_E,    KC_A,    KC_I,    KC_SCLN,
        KC_LSFT, KC_X,    KC_QUOT, KC_B,    KC_M,    KC_J,                               KC_P,    KC_G,    KC_COMM, KC_DOT,  KC_SLSH, DF(QWERTY),
                                         MO(NAVIGATION), MO(SYMBOLS), KC_ENT,    KC_BSPC, KC_SPC, KC_RSFT
    ),

    [QWERTY] = LAYOUT_split_3x6_3(
        KC_TAB,  KC_Q,    KC_W,    KC_E,    KC_R,    KC_T,                               KC_Y,    KC_U,    KC_I,    KC_O,    KC_P,    KC_BSPC,
        KC_LCTL, KC_A,    KC_S,    KC_D,    KC_F,    KC_G,                               KC_H,    KC_J,    KC_K,    KC_L,    KC_SCLN, KC_QUOT,
        KC_LSFT, KC_Z,    KC_X,    KC_C,    KC_V,    KC_B,                               KC_N,    KC_M,    KC_COMM, KC_DOT,  KC_SLSH, DF(GAMING),
                                         KC_LGUI, KC_SPC, KC_BSPC,            KC_ENT, KC_SPC, KC_RALT
    ),

    [GAMING] = LAYOUT_split_3x6_3(
        KC_NO, KC_NO,    KC_Q,     KC_W,    KC_E,    KC_R,                                KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,
        KC_NO, KC_G,     KC_S,     KC_A,    KC_D,    KC_F,                                KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,    DF(QWERTY),
        KC_NO, KC_NO,    KC_Z,     KC_X,    KC_C,    KC_NO,                               KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,    DF(SEMIMAK),
                                         KC_NO,   MO(SYMBOLS), KC_NO,       KC_DEL, KC_SPC, KC_RSFT
    ),

    /* Stack Layers */
    [SYMBOLS] = LAYOUT_split_3x6_3(
        KC_NO, KC_9,     KC_5,     KC_1,     KC_3,     KC_7,                                KC_6,     KC_2,     KC_0,     KC_4,     KC_8,     KC_NO,
        KC_NO, KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,                               KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,
        KC_NO, KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,                               KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,
                                            KC_TRNS, KC_TRNS, KC_TRNS,          KC_TRNS, KC_TRNS, KC_TRNS
    ),

    [NAVIGATION] = LAYOUT_split_3x6_3(
        KC_NO, KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,                               KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,
        KC_NO, KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,                               KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,
        KC_NO, KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,                               KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,
                                            KC_TRNS, KC_TRNS, KC_TRNS,          MO(FUN), KC_TRNS, KC_TRNS
    ),

    [FUN] = LAYOUT_split_3x6_3(
        KC_NO, KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,                               KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,    QK_CLEAR_EEPROM,
        KC_NO, KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,                               KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,    QK_MAKE,
        KC_NO, KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,                               KC_NO,    KC_NO,    KC_NO,    KC_NO,    KC_NO,    QK_BOOT,
                                            KC_TRNS, KC_TRNS, KC_TRNS,          KC_TRNS, KC_TRNS, KC_TRNS
    )
};
