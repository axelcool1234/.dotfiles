// Copyright 2022 beekeeb
// SPDX-License-Identifier: GPL-2.0-or-later

#include QMK_KEYBOARD_H
#include "oneshot.h"

/* TODO:
 * Vim layer?
 * LaTeX layer?
 * Common macros in the _FUN layer?
 * Implement leader key (put in empty spot of symbol layer or empty spot in Semimak layer)?
 * Implement GPIO manipulation to control LED light on the WeAct RP2040s
 * Implement SHIFT + QK_REP = QK_AREP as a key override somehow
 * Additional extend stack layers?
*/

/* Layers */
enum layers {
    // base
    _SEMIMAK,
    _QWERTY,
    _GAME,
    // tri layer
    _EXTEND,
    _SYM,
    _NUM,
    // extend stack
    _MOUSE,
    _MEDIA,
    _FUN,
};

/* Key Codes */
enum keycodes {
    // Custom oneshot mod implementation with no timers, courtesy of Callum's mods.
    OS_GUI = SAFE_RANGE,
    OS_ALT,
    OS_SFT,
    OS_CTL,
    OS_HYP,

    /* Layer switches */
    LA_SYM,
    LA_EXTEND,

    /* Macros */
    M_UP_DIR, // ../
    M_DCOLN,  // ::

    /* Multi-Repeat Key */
    //REPEAT,
};

/* Misc */
#define XXXXXXXX  XXXXXXX
#define ________  _______
#define VOL_DOWN  KC_KB_VOLUME_DOWN
#define VOL_UP    KC_KB_VOLUME_UP
#define CL_EEP    QK_CLEAR_EEPROM
#define HOME_CAP  QK_CAPS_WORD_TOGGLE

/* Custom keys */
#define PASTE     LCTL(KC_V)
#define COPY      LCTL(KC_C)
#define CUT       LCTL(KC_X)
#define UNDO      LCTL(KC_Z)
#define REDO      LCTL(KC_Y)
#define P_FUN     OSL(_FUN)
#define SFT_BSPC  SFT_T(KC_BSPC)

/* Switch base */
#define D_QWERTY  DF(_QWERTY)
#define D_GAMING  DF(_GAME)
#define D_SEMIMAK DF(_SEMIMAK)

/* Switch layer */
#define LA_MOUSE    TG(_MOUSE)
#define LA_MEDIA    TG(_MEDIA)

/* Keymaps */
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    /* Base Layers */
    [_SEMIMAK] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       KC_ESC,   KC_F,   KC_L,     KC_H,    KC_V,    KC_Z,       /*-------*/       KC_Q,    KC_W,    KC_U,    KC_O,   KC_Y,    KC_GRV,
    //|--------+--------+--------+--------+--------+--------|     |SEMIMAK|      |--------+--------+--------+--------+--------+--------|
       HOME_CAP, KC_S,   KC_R,     KC_N,    KC_T,    KC_K,       /*-------*/       KC_C,    KC_D,    KC_E,    KC_A,   KC_I,    KC_ENT,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       P_FUN,    KC_X,   KC_QUOT,  KC_B,    KC_M,    KC_J,                         KC_P,    KC_G,    KC_COMM, KC_DOT, KC_SLSH, XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           SFT_BSPC, QK_REP, LA_SYM,    LA_EXTEND, KC_SPC,  QK_AREP
                                        //`--------------------------'  `--------------------------'
                                        //
    ),

    [_QWERTY] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       KC_ESC,   KC_Q,    KC_W,    KC_E,    KC_R,    KC_T,        /*------*/       KC_Y,    KC_U,    KC_I,    KC_O,    KC_P,    KC_ESC,
    //|--------+--------+--------+--------+--------+--------|      |QWERTY|      |--------+--------+--------+--------+--------+--------|
       HOME_CAP, KC_A,    KC_S,    KC_D,    KC_F,    KC_G,        /*------*/       KC_H,    KC_J,    KC_K,    KC_L,    KC_QUOT, KC_ENT,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       P_FUN,    KC_Z,    KC_X,    KC_C,    KC_V,    KC_B,                         KC_N,    KC_M,    KC_COMM, KC_DOT,  KC_SLSH, XXXXXXX,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           SFT_BSPC, KC_BSPC, LA_SYM,   LA_EXTEND, KC_SPC,  QK_AREP
                                        //`--------------------------'  `--------------------------'
    ),

    [_GAME] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       XXXXXXXX,  KC_G,   KC_Q,    KC_W,    KC_E,    KC_R,        /*------*/      XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|      |Gaming|      |--------+--------+--------+--------+--------+--------|
       XXXXXXXX, KC_LSFT, KC_S,    KC_A,    KC_D,    KC_F,        /*------*/      XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,XXXXXXXX, KC_Z,    KC_X,    KC_C,   XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,D_SEMIMAK,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           XXXXXXXX, KC_SPC, XXXXXXXX,   XXXXXXXX,XXXXXXXX,XXXXXXXX
                                        //`--------------------------'  `--------------------------'
    ),

    /* Tri Layer */
    [_EXTEND] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       ________,________,________,________,________,________,                     ________,________,________,________,________,________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       LA_MEDIA, OS_GUI,  OS_ALT,  OS_SFT,  OS_CTL, LA_MOUSE,                     ________,KC_LEFT, KC_DOWN,  KC_UP,  KC_RIGHT,________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________, UNDO,    CUT,     COPY,    PASTE,   REDO,                        ________,________,________,________,________,________,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           QK_LEAD, KC_ENT,  ________,   ________,________,________
                                        //`--------------------------'  `--------------------------'
    ),

    [_SYM] = LAYOUT_split_3x6_3( // Mirrored version of Pascal Getreuer's symbol layer, with the opening and closing braces flipped for inward rolls.
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       ________,KC_PERC, KC_LBRC, KC_RBRC, M_DCOLN, KC_AMPR,                      KC_DOT,  KC_DQT,  KC_LT,   KC_GT,   KC_QUOT, ________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________,KC_QUES, KC_LPRN, KC_RPRN, KC_COLN, KC_PIPE,                      KC_HASH, KC_EQL,  KC_MINS, KC_PLUS, KC_EXLM, ________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________,KC_AT,   KC_LCBR, KC_RCBR, KC_DLR,  KC_TILD,                      M_UP_DIR,KC_BSLS, KC_SLSH, KC_ASTR, KC_CIRC, ________,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           ________,________,________,   ________, KC_UNDS,QK_REP
                                        //`--------------------------'  `--------------------------'
    ),

    [_NUM] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       ________,  KC_9,   KC_5,    KC_1,   KC_3,     KC_7,                          KC_6,    KC_2,    KC_0,    KC_4,    KC_8,  ________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________, OS_GUI,  OS_ALT,  OS_SFT, OS_CTL,  ________,                     ________,________,________,________,________,________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________,________,________,________,________,________,                     ________,________,________,________,________,________,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           ________,________,________,   ________,________,________
                                        //`--------------------------'  `--------------------------'
    ),

    /* Extend Stack */
    [_MOUSE] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       ________,________,________,________,________,________,                       REDO,  KC_PASTE, KC_COPY, KC_CUT,  KC_UNDO, KC_ACL0,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________, OS_GUI,  OS_ALT,  OS_SFT,  OS_CTL, ________,                     ________,KC_MS_L,  KC_MS_D, KC_MS_U, KC_MS_R, KC_ACL1,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________,________,________,________,________,________,                     ________,KC_WH_L,  KC_WH_D, KC_WH_U, KC_WH_R, KC_ACL2,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           ________,________,________,   ________,________,________
                                        //`--------------------------'  `--------------------------'
    ),

    [_MEDIA] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       ________,________,________,________,________,________,                     ________,________,________,________,________,________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________, OS_GUI,  OS_ALT,  OS_SFT,  OS_CTL, ________,                      KC_MPLY,KC_MRWD, VOL_DOWN, VOL_UP, KC_MFFD, ________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________,________,________,________,________,________,                     ________,________,KC_BRID,  KC_BRIU,________,________,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           ________,________,________,   ________,________,________
                                        //`--------------------------'  `--------------------------'
    ),

    [_FUN] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
      D_SEMIMAK, KC_F9,   KC_F5,   KC_F1,   KC_F3,   KC_F7,                        KC_F6,   KC_F2,   KC_F10,  KC_F4,   KC_F8,  CL_EEP,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       D_QWERTY, OS_GUI,  OS_ALT,  OS_SFT,  OS_CTL,  KC_F11,                       KC_F12,  DM_PLY1, DM_PLY2,XXXXXXXX,XXXXXXXX,QK_MAKE,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       D_GAMING,  UNDO,    CUT,     COPY,   PASTE,    REDO,                        DM_RSTP, DM_REC1, DM_REC2,XXXXXXXX,XXXXXXXX,QK_BOOT,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           ________,________,________,   ________,________,________
                                        //`--------------------------'  `--------------------------'
    ),
};
/* Thumb Cluster Overrides */
const key_override_t space_key_override = ko_make_basic(MOD_MASK_SHIFT, KC_SPC,  KC_TAB);

/* Base Layer Overrides */
const key_override_t comma_key_override = ko_make_basic(MOD_MASK_SHIFT, KC_COMM, KC_EXLM);
const key_override_t dot_key_override =   ko_make_basic(MOD_MASK_SHIFT, KC_DOT, KC_QUES);
const key_override_t slash_key_override = ko_make_basic(MOD_MASK_SHIFT, KC_SLSH, KC_SCLN);
const key_override_t **key_overrides = (const key_override_t *[]){
    /* Thumb Cluster */
    &space_key_override,
    /* Base Layer */
    &comma_key_override,
    &dot_key_override,
    &slash_key_override,
    NULL // Null terminate the array of overrides!
};

/* Combos
const uint16_t PROGMEM delete_combo[] = {KC_SPC, KC_BSPC, COMBO_END};
combo_t key_combos[] = {
    COMBO(delete_combo, KC_DEL),
};
*/

/* Repeat Key */
//bool remember_last_key_user(uint16_t keycode, keyrecord_t* record,
//                            uint8_t* remembered_mods) {
//    switch (keycode) {
//        case REPEAT:
//            return false;  // Ignore REPEAT key.
//    }
//    return true;  // Other keys can be repeated.
//}
//
//static void process_repeat(uint16_t keycode, uint8_t mods) {
//    if (get_mods() & MOD_MASK_SHIFT) { // SHIFT + REPEAT = QK_AREP
//        switch (keycode) {
//            case KC_A: SEND_STRING(/*a*/"tion"); break;
//            case KC_I: SEND_STRING(/*i*/"tion"); break;
//            case KC_S: SEND_STRING(/*s*/"sion"); break;
//            case KC_T: SEND_STRING(/*t*/"heir"); break;
//            case KC_W: SEND_STRING(/*w*/"hich"); break;
//        }
//    }
//    else { // REPEAT = QK_REP
//
//    }
//}
bool remember_last_key_user(uint16_t keycode, keyrecord_t* record,
                            uint8_t* remembered_mods) {
    switch (keycode) {
        case LA_SYM:
        case LA_EXTEND:
            return false;  // Ignore
    }

    return true;  // Other keys can be repeated.
}


/* Callum Oneshots */
bool is_oneshot_cancel_key(uint16_t keycode) {
    switch (keycode) {
    case LA_SYM:
    case LA_EXTEND:
        return true;
    default:
        return false;
    }
}

bool is_oneshot_ignored_key(uint16_t keycode) {
    switch (keycode) {
    case LA_SYM:
    case LA_EXTEND:
    case KC_LSFT:
    case OS_GUI:
    case OS_ALT:
    case OS_SFT:
    case OS_CTL:
        return true;
    default:
        return false;
    }
}

oneshot_state os_sft_state = os_up_unqueued;
oneshot_state os_ctl_state = os_up_unqueued;
oneshot_state os_alt_state = os_up_unqueued;
oneshot_state os_gui_state = os_up_unqueued;

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    /* Callum Oneshots */
    update_oneshot(
            &os_sft_state, KC_LSFT, OS_SFT,
            keycode, record
            );
    update_oneshot(
            &os_ctl_state, KC_LCTL, OS_CTL,
            keycode, record
            );
    update_oneshot(
            &os_alt_state, KC_LALT, OS_ALT,
            keycode, record
            );
    update_oneshot(
            &os_gui_state, KC_LGUI, OS_GUI,
            keycode, record
            );
    switch (keycode) {
        /* Tri Layer */
        case LA_EXTEND:
            if ((! record->tap.count) && (! record->event.pressed)) {
                /* turn off extend stack once extend is off */
                layer_off(_MOUSE);
                layer_off(_MEDIA);
            }
            if (record->event.pressed) {
                layer_on(_EXTEND);
                update_tri_layer(_SYM, _EXTEND, _NUM);
            }
            else {
                layer_off(_EXTEND);
                update_tri_layer(_SYM, _EXTEND, _NUM);
            }
            return false;
        case LA_SYM:
            if (record->event.pressed) {
                layer_on(_SYM);
                update_tri_layer(_SYM, _EXTEND, _NUM);
            }
            else {
                layer_off(_SYM);
                update_tri_layer(_SYM, _EXTEND, _NUM);
            }
            return false;
        /* Macros */
        case M_UP_DIR:
            if (record->event.pressed) {
                SEND_STRING("../");
            }
            else {

            }
            return false;
        case M_DCOLN:
            if (record->event.pressed) {
                SEND_STRING("::");
            }
            else {

            }
            return false;
        /* Custom Keys
        case REPEAT:
            if (record->event.pressed) {
                process_repeat(get_last_keycode(), get_last_mods());
            }
            return false;
        */
    }
    return true;
}
