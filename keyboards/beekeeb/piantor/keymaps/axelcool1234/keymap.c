// Copyright 2022 beekeeb
// SPDX-License-Identifier: GPL-2.0-or-later

#include QMK_KEYBOARD_H

/* Layers */
enum layers {
    // base
    _SEMIMAK,
    _QWERTY,
    _GAME,
    // stack
    _NAV,
    _MOUSE,
    _MEDIA,
    _NUM,
    _SYM,
    _FUN,
    _BUTTON
};

/* Misc */
#define XXXXXXXX XXXXXXX

/* Homerow mods */
#define HOME_CAP QK_CAPS_WORD_TOGGLE

// Left homerow mods
#define HOME_S LGUI_T(KC_S)
#define HOME_R LALT_T(KC_R)
#define HOME_N LSFT_T(KC_N)
#define HOME_T LCTL_T(KC_T)

// Right homerow mods
#define HOME_D RCTL_T(KC_D)
#define HOME_E RSFT_T(KC_E)
#define HOME_A LALT_T(KC_A)
#define HOME_I RGUI_T(KC_I)

/* Thumb cluster mods */
#define P_BUTTON OSL(_BUTTON)

// Left thumb cluster mods
#define TH_SPC LT(_NAV,   KC_SPC)
#define TH_TAB LT(_MOUSE, KC_TAB)
#define TH_ESC LT(_MEDIA, KC_ESC)

// Right thumb cluster mods
#define TH_BSPC LT(_NUM, KC_BSPC)
#define TH_ENT  LT(_SYM, KC_ENT)
#define TH_DEL  LT(_FUN, KC_DEL)

/* Switch base */
#define D_QWERTY  DF(_QWERTY)
#define D_GAME    DF(_GAME)
#define D_SEMIMAK DF(_SEMIMAK)

/* Keymaps */
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    /* Base Layers */
    [_SEMIMAK] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       KC_ESC,   KC_F,   KC_L,     KC_H,    KC_V,    KC_Z,       /*-------*/       KC_Q,    KC_W,    KC_U,    KC_O,   KC_Y,    KC_ESC,
    //|--------+--------+--------+--------+--------+--------|     |SEMIMAK|      |--------+--------+--------+--------+--------+--------|
       HOME_CAP, KC_S,   KC_R,     KC_N,    KC_T,    KC_K,       /*-------*/       KC_C,    KC_D,    KC_E,    KC_A,   KC_I,    KC_SCLN,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       P_BUTTON, KC_X,   KC_QUOT,  KC_B,    KC_M,    KC_J,                         KC_P,    KC_G,    KC_COMM, KC_DOT, KC_SLSH, D_QWERTY,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                            KC_ESC,  KC_SPC, KC_TAB,      KC_ENT, KC_BSPC, KC_DEL
                                        //`--------------------------'  `--------------------------'
    ),

    [_QWERTY] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
        KC_TAB,  KC_Q,    KC_W,    KC_E,    KC_R,    KC_T,        /*------*/       KC_Y,    KC_U,    KC_I,    KC_O,    KC_P,    KC_BSPC,
    //|--------+--------+--------+--------+--------+--------|      |QWERTY|      |--------+--------+--------+--------+--------+--------|
        KC_LCTL, KC_A,    KC_S,    KC_D,    KC_F,    KC_G,        /*------*/       KC_H,    KC_J,    KC_K,    KC_L,    KC_SCLN, KC_QUOT,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
        KC_LSFT, KC_Z,    KC_X,    KC_C,    KC_V,    KC_B,                         KC_N,    KC_M,    KC_COMM, KC_DOT,  KC_SLSH, D_GAME,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                            KC_LGUI, KC_SPC, KC_BSPC,     KC_ENT,  KC_SPC,  KC_RALT
                                        //`--------------------------'  `--------------------------'
    ),

    [_GAME] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       XXXXXXXX,  KC_G,   KC_Q,    KC_W,    KC_E,    KC_R,        /*------*/      XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|      |Gaming|      |--------+--------+--------+--------+--------+--------|
       XXXXXXXX, KC_LSFT,   KC_S,    KC_A,    KC_D,    KC_F,        /*------*/      XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,D_QWERTY,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX, KC_Z,    KC_X,    KC_C,   XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,D_SEMIMAK,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           XXXXXXXX, KC_SPC, XXXXXXXX,   XXXXXXXX,XXXXXXXX,XXXXXXXX
                                        //`--------------------------'  `--------------------------'
    ),

    /* Stack Layers */
    [_NAV] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           XXXXXXXX,XXXXXXXX,XXXXXXXX,   XXXXXXXX,XXXXXXXX,XXXXXXXX
                                        //`--------------------------'  `--------------------------'
    ),
    [_MOUSE] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           XXXXXXXX,XXXXXXXX,XXXXXXXX,   XXXXXXXX,XXXXXXXX,XXXXXXXX
                                        //`--------------------------'  `--------------------------'
    ),
    [_MEDIA] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           XXXXXXXX,XXXXXXXX,XXXXXXXX,   XXXXXXXX,XXXXXXXX,XXXXXXXX
                                        //`--------------------------'  `--------------------------'
    ),
    [_NUM] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           XXXXXXXX,XXXXXXXX,XXXXXXXX,   XXXXXXXX,XXXXXXXX,XXXXXXXX
                                        //`--------------------------'  `--------------------------'
    ),
    [_SYM] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           XXXXXXXX,XXXXXXXX,XXXXXXXX,   XXXXXXXX,XXXXXXXX,XXXXXXXX
                                        //`--------------------------'  `--------------------------'
    ),
    [_FUN] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           XXXXXXXX,XXXXXXXX,XXXXXXXX,   XXXXXXXX,XXXXXXXX,XXXXXXXX
                                        //`--------------------------'  `--------------------------'
    ),
    [_BUTTON] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           XXXXXXXX,XXXXXXXX,XXXXXXXX,   XXXXXXXX,XXXXXXXX,XXXXXXXX
                                        //`--------------------------'  `--------------------------'
    ),
};

/* Additional Functionality */
