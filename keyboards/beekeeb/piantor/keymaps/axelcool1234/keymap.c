// Copyright 2022 beekeeb
// SPDX-License-Identifier: GPL-2.0-or-later

#include QMK_KEYBOARD_H
// Code provided by Pascal Getreuer.
#include "sentence_case.h"
// Code provided by Callum.
#include "oneshot.h"

/* TODO:
 * Vim Mode (https://github.com/andrewjrae/qmk-vim)
 * LaTeX layer?
 * Common macros in the _FUN layer?
 * Implement GPIO manipulation to control LED light on the WeAct RP2040s (Possibly for a "lock" layer that locks my keyboard. A specific tap-dance only I know will unlock it)
 * Additional extend stack layers?
 * Additional tri-layer?
 * Find a use for bottom right key on SEMIMAK layer.
*/

/* Layers */
enum layers {
    // base
    _SEMIMAK,
    _SHIFT,
    _GAME,
    // tri layer
    _EXTEND,
    _SYM,
    _NUM,
    // extend stack
    _MOUSE,
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

    /* Macros */
    M_UP_DIR, // ../
    M_DCOLN,  // ::

    /* Magic Keys */
    MAG_1,
    MAG_2,
    MAG_3,
    MAG_4,

    /* Toggle Sentence Case */
    SENTENCE,
};

/* Misc */
#define XXXXXXXX  XXXXXXX
#define ________  _______

/* Function layer keys */
#define CL_EEP    QK_CLEAR_EEPROM
#define HOME_CAP  QK_CAPS_WORD_TOGGLE

/* Extend layer keys */
#define PASTE     LCTL(KC_V)
#define COPY      LCTL(KC_C)
#define CUT       LCTL(KC_X)
#define UNDO      LCTL(KC_Z)
#define REDO      LCTL(KC_Y)

/* Base layer keys */
#define OS_FUN    OSL(_FUN)
#define T_CAPS    TD(TD_CAPS)

/* SFTSEMI layer keys */
#define SFT_QT    S(KC_QUOT)
#define SFT_COM   S(KC_COMM)
#define SFT_DOT   S(KC_DOT)
#define SFT_SLS   S(KC_SLSH)

/* Switch base */
#define D_GAMING  DF(_GAME)
#define D_SEMIMAK DF(_SEMIMAK)

/* Switch layer
 * LT means Layer-Tap
 * LA means Layer-Activate (the same as an MO() call, deactivates upon keyup)
 * Tri-layers:
 * LT_SFT + LT_EXTEND = _NUM layer activation
 * LT_SYM + LT_EXTEND = NONE for now.
 * */
#define LA_MOUSE    TG(_MOUSE)
#define LT_EXTEND   TD(TD_MOD)
#define LT_SYM      LT(_SYM, KC_ENT)
#define LT_SFT      LT(_SHIFT, KC_BSPC)

/* Magic */
#define magic_case(trigger, supplement) \
    case trigger: \
        SEND_STRING(supplement); \
        return

/* Tap Dance */
typedef enum {
    TD_NONE,
    TD_UNKNOWN,
    TD_SINGLE_TAP,
    TD_SINGLE_HOLD,
    TD_DOUBLE_TAP,
    TD_DOUBLE_HOLD,
    TD_DOUBLE_SINGLE_TAP, // Send two single taps
    TD_TRIPLE_TAP,
    TD_TRIPLE_HOLD,
    TD_TRIPLE_SINGLE_TAP, // Send three single taps
    TD_QUADRUPLE_TAP,
    TD_QUADRUPLE_HOLD,
    TD_QUADRUPLE_SINGLE_TAP, // Send four single taps
} td_state_t;

typedef struct {
    bool is_press_action;
    td_state_t state;
} td_tap_t;

// Tap Dance declaratigions
enum {
    TD_CAPS,
    TD_MOD,
};


/* Keymaps */
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    /* Base Layers */
    [_SEMIMAK] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       KC_ESC,   KC_F,   KC_L,     KC_H,    KC_V,    KC_Z,       /*-------*/       KC_Q,    KC_W,    KC_U,    KC_O,   KC_Y,    KC_GRV,
    //|--------+--------+--------+--------+--------+--------|     |SEMIMAK|      |--------+--------+--------+--------+--------+--------|
       T_CAPS,   KC_S,   KC_R,     KC_N,    KC_T,    KC_K,       /*-------*/       KC_C,    KC_D,    KC_E,    KC_A,   KC_I,    KC_ENT,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       OS_FUN,   KC_X,   KC_QUOT,  KC_B,    KC_M,    KC_J,                         KC_P,    KC_G,    KC_COMM, KC_DOT, KC_SLSH, XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                            MAG_1, QK_REP,   LT_SYM,      LT_SFT,  KC_SPC,  LT_EXTEND
                                        //`--------------------------'  `--------------------------'
    ),
    [_SHIFT] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       KC_ESC,   S(KC_F), S(KC_L), S(KC_H), S(KC_V), S(KC_Z), /*-------------*/    S(KC_Q), S(KC_W), S(KC_U), S(KC_O), S(KC_Y), S(KC_GRV),
    //|--------+--------+--------+--------+--------+--------   |SHIFT SEMIMAK|   |--------+--------+--------+--------+--------+--------|
       T_CAPS,   S(KC_S), S(KC_R), S(KC_N), S(KC_T), S(KC_K), /*-------------*/    S(KC_C), S(KC_D), S(KC_E), S(KC_A), S(KC_I), S(KC_ENT),
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       OS_FUN,   S(KC_X), SFT_QT,  S(KC_B), S(KC_M), S(KC_J),                      S(KC_P), S(KC_G),KC_EXLM, KC_QUES, KC_SCLN, XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                            MAG_2,   MAG_3,  ________,   ________,________,________
                                        //`--------------------------'  `--------------------------'
    ),

    [_GAME] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       XXXXXXXX, KC_G,    KC_Q,    KC_W,    KC_E,    KC_R,        /*------*/      XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|      |Gaming|      |--------+--------+--------+--------+--------+--------|
       XXXXXXXX, KC_LSFT, KC_S,    KC_A,    KC_D,    KC_F,        /*------*/      XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       OS_FUN,  XXXXXXXX, KC_Z,    KC_X,    KC_C,   XXXXXXXX,                     XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,XXXXXXXX,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           XXXXXXXX, KC_SPC, XXXXXXXX,   XXXXXXXX,XXXXXXXX,XXXXXXXX
                                        //`--------------------------'  `--------------------------'
    ),

    [_EXTEND] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       ________,________,________,________,________,________,                     ________,________,________,________,________,________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       LA_MOUSE, OS_GUI,  OS_ALT,  OS_SFT,  OS_CTL, ________,                     ________,KC_LEFT, KC_DOWN,  KC_UP,  KC_RIGHT,________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________, UNDO,    CUT,     COPY,    PASTE,   REDO,                        ________,________,________,________,________,________,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                            MAG_4,   KC_TAB, QK_LEADER,  ________,________,________
                                        //`--------------------------'  `--------------------------'
    ),

    [_SYM] = LAYOUT_split_3x6_3( // Mirrored version of Pascal Getreuer's symbol layer, with the opening and closing braces flipped for inward rolls.
                                 // Additionally, having it flipped means KC_MINS/KC_SLSH can be swapped with KC_PLUS/KC_ASTR, since those are more
                                 // common symbols and should be on the middle finger. The arrow operator -> will not be a SFB as it would be if it
                                 // were not mirrored.
                                 // Downsides to this change:
                                 // - The arrow operator -> is now an outward roll rather than an inward roll.
                                 // - The opening braces (, [, { are no longer on the middle finger, but the ring finger, despite these being
                                 //   more common than the closing braces ), ], } which are no longer on the ring finger, but the middle finger.
                                 // Upsides to this change:
                                 // - Symbols ../, /, and \ are now all next to each other.
                                 // - (), [], and {} are now inward rolls rather than outward rolls.
                                 // - Symbols - and / are now on a more dominant finger (which is good since they're more common than + and *).
                                 //
                                 // The reason the upsides outweigh the downsides (justifying the mirroring):
                                 // - Vim usage means autoclosing braces aren't helpful, so closing braces will be typed anyways, meaning the frequency of
                                 //   opening and closing brace typed should be around the same. This also means the middle and ring finger will get equal
                                 //   usage. A plus is now these symbols (), [], {} are inward rolls!
                                 // - Easier mental compartmentalization of the symbol layer with the slashes and directory macro being grouped together.
                                 // - The arrow operator -> being an outward roll is arguably better than (), [], and {} being outward rolls. Even if the
                                 //   usage of each in programming were equal, this mirroring of Getreuer's symbol layer has gained two more additional
                                 //   inward rolls. The arrow operator -> would have to be more common than (), [], and {} combined for this to be considered
                                 //   a downside.
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       ________,KC_PERC, KC_LBRC, KC_RBRC, KC_DCOLN, KC_AMPR,                     KC_DOT,  KC_DQT,  KC_LT,   KC_GT,   KC_QUOT, ________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________,KC_QUES, KC_LPRN, KC_RPRN, KC_COLN, KC_PIPE,                      KC_HASH, KC_EQL,  KC_MINS, KC_PLUS, KC_EXLM, ________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________,KC_AT,   KC_LCBR, KC_RCBR, KC_DLR,  KC_TILD,                      M_UP_DIR,KC_BSLS, KC_SLSH, KC_ASTR, KC_CIRC, ________,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           ________,________,_______,    ________,KC_UNDS, KC_SCLN
                                        //`--------------------------'  `--------------------------' <
    ),

    [_NUM] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       ________, KC_PERC, KC_PLUS, KC_MINS, KC_EQL,  KC_COMM,                       KC_DOT, KC_AMPR,  KC_LT,   KC_GT, KC_PIPE, ________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________,  KC_9,   KC_5,    KC_1,    KC_3,    KC_7,                          KC_6,    KC_2,    KC_0,    KC_4,    KC_8,  ________,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________, OS_GUI,  OS_ALT,  OS_SFT,  OS_CTL,  KC_EQL,                       KC_MINS, KC_PLUS, KC_SLSH, KC_ASTR, KC_CIRC,________,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           ________,________,________,   ________,________,________
                                        //`--------------------------'  `--------------------------'
    ),

    /* Extend Stack */
    [_MOUSE] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       ________,________,________,________,________,________,                     ________,________, KC_MS_U,________,________, KC_ACL0,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________, OS_GUI,  OS_ALT,  OS_SFT,  OS_CTL, ________,                     KC_WH_L, KC_MS_L,  KC_MS_D, KC_MS_R, KC_WH_D, KC_ACL1,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       ________,________,________,________,________,________,                     ________,KC_WH_L,  KC_WH_D, KC_WH_U, KC_WH_R, KC_ACL2,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           ________,________,________,   ________,________,________
                                        //`--------------------------'  `--------------------------'
    ),

    [_FUN] = LAYOUT_split_3x6_3(
    //,-----------------------------------------------------.                    ,-----------------------------------------------------.
       XXXXXXXX, KC_F9,   KC_F5,   KC_F1,   KC_F3,   KC_F7,                        KC_F6,   KC_F2,   KC_F10,  KC_F4,   KC_F8,  CL_EEP,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       SENTENCE, OS_GUI,  OS_ALT,  OS_SFT,  OS_CTL,  KC_F11,                       KC_F12,  DM_PLY1, DM_PLY2,XXXXXXXX,XXXXXXXX,QK_MAKE,
    //|--------+--------+--------+--------+--------+--------|                    |--------+--------+--------+--------+--------+--------|
       XXXXXXXX,  UNDO,    CUT,     COPY,   PASTE,    REDO,                        DM_RSTP, DM_REC1, DM_REC2,XXXXXXXX,XXXXXXXX,QK_BOOT,
    //|--------+--------+--------+--------+--------+--------+--------|  |--------+--------+--------+--------+--------+--------+--------|
                                           ________,________,D_SEMIMAK,  D_GAMING,________,________
                                        //`--------------------------'  `--------------------------'
    ),
};
/* Sentence Case */
char sentence_case_press_user(uint16_t keycode,
                              keyrecord_t* record,
                              uint8_t mods) {
   if ((mods & ~(MOD_MASK_SHIFT | MOD_BIT(KC_RALT))) == 0) {
    const bool shifted = mods & MOD_MASK_SHIFT;
    switch (keycode) {
      case LT_SYM:
      case LT_SFT:
      case LT_EXTEND:
      case KC_LCTL ... KC_RGUI:  // Mod keys.
        return '\0';  // These keys are ignored.
      case KC_A ... KC_Z:
        return 'a';  // Letter key.
      case KC_EXLM:
      case KC_QUES:
      case KC_DOT:
        return '.';
      case KC_COMM:
        return shifted ? '.' : '#';
      case KC_1 ... KC_0:  // 1 2 3 4 5 6 7 8 9 0
      case KC_MINS ... KC_SCLN:  // - = [ ] ; backslash
      case KC_GRV:
      case KC_SLSH:
        return '#';
      case KC_SPC:
        return ' ';  // Space key.
      case KC_QUOT:
        return '\'';  // Quote key.
    }
  }
  // Otherwise clear Sentence Case to initial state.
  sentence_case_clear();
  return '\0';
}

/* Magic Keys */
bool get_repeat_key_eligible_user(uint16_t keycode, keyrecord_t* record, uint8_t* remembered_mods) {
    switch (keycode) {
        // Ignore Custom Magic Keys
        case MAG_1:
        case MAG_2:
        case MAG_3:
        case MAG_4:
            return false;
        // Forget Shift on letter keys when Shift is the only mod being pressed.
        case KC_A ... KC_Z:
            if ((*remembered_mods & ~(MOD_MASK_SHIFT)) == 0) {
                *remembered_mods &= ~MOD_MASK_SHIFT;
            }
            break;
    }

    return true;
}
void process_magic_key_1(uint16_t prev_keycode, uint8_t prev_mods) {
    switch (prev_keycode) {
        magic_case(KC_C, "y");
        magic_case(KC_P, "y");
        magic_case(KC_D, "y");
        magic_case(KC_G, "y");
        magic_case(KC_Z, "y");
        magic_case(KC_Y, "p");
        magic_case(KC_R, "l");
        magic_case(KC_K, "s");
        magic_case(KC_L, "k");
        magic_case(KC_S, "k");
        magic_case(KC_U, "e");
        magic_case(KC_E, "u");
        magic_case(KC_O, "a");
        magic_case(KC_A, "o");
         case KC_DOT:
            if (prev_mods & MOD_MASK_SHIFT) {
                SEND_STRING("=");
                return;
            }
            else {
                SEND_STRING("\\");
                return;
            }
        case KC_COMM:
            if (prev_mods & MOD_MASK_SHIFT) {
                SEND_STRING("=");
                return;
            }
            else {
                SEND_STRING(" but");
                return;
            }
        magic_case(KC_EQL, ">");
        magic_case(KC_MINS, ">");
        magic_case(KC_Q, "mlativ");
        magic_case(KC_H, "oa");
        magic_case(KC_I, "on");
        magic_case(KC_N, "ion");
        magic_case(KC_V, "er");
        magic_case(KC_X, "es");
        magic_case(KC_M, "ent");
        magic_case(KC_T, "ment");
        magic_case(KC_J, "ust");
        magic_case(KC_B, "efore");
        magic_case(KC_W, "hich");
        magic_case(KC_1 ... KC_0, ".");
        magic_case(KC_SPC, "the");
    }
}
void process_magic_key_2(uint16_t prev_keycode, uint8_t prev_mods) {
    switch (prev_keycode) {
        magic_case(KC_B, "ecome");
        magic_case(KC_F, "ollow");
        magic_case(KC_N, "eighbor");
        magic_case(KC_H, "owever");
        magic_case(KC_U, "pgrade");
        magic_case(KC_O, "ther");
        magic_case(KC_A, "lready");
        magic_case(KC_P, "sych");
        magic_case(KC_I, "'ll");
        magic_case(KC_K, "now");
        magic_case(KC_T, "hough");
        magic_case(KC_L, "ittle");
        magic_case(KC_M, "ight");
        magic_case(KC_R, "ight");
        magic_case(KC_J, "udge");
        magic_case(KC_C, "ould");
        magic_case(KC_D, "evelop");
        magic_case(KC_G, "eneral");
        magic_case(KC_W, "here");
        magic_case(KC_S, "hould");
        magic_case(KC_DOT, "org");
        magic_case(KC_COMM, " however");
    }
}
void process_magic_key_3(uint16_t prev_keycode, uint8_t prev_mods) {
    switch (prev_keycode) {
        magic_case(KC_B, "etween");
        magic_case(KC_N, "umber");
        magic_case(KC_U, "pdate");
        magic_case(KC_A, "bout");
        magic_case(KC_W, "orld");
        magic_case(KC_G, "overn");
        magic_case(KC_P, "rogram");
        magic_case(KC_Q, "uestion");
        magic_case(KC_C, "rowd");
        magic_case(KC_S, "chool");
        magic_case(KC_T, "hrough");
        magic_case(KC_M, "anage");
        magic_case(KC_O, "xygen");
        magic_case(KC_I, "'m");
        magic_case(KC_E, "'re");
        magic_case(KC_DOT, "com");
        magic_case(KC_COMM, " since");
    }
}

void process_magic_key_4(uint16_t prev_keycode, uint8_t prev_mods) {
    switch (prev_keycode) {
        // Blank for now
    }
}

bool remember_last_key_user(uint16_t keycode, keyrecord_t* record,
                            uint8_t* remembered_mods) {
    switch (keycode) {
        /* Magic Keys */
        case MAG_1:
        case MAG_2:
        case MAG_3:
        case MAG_4:
            return false;  // Ignore
    }

    return true;  // Other keys can be repeated.
}
/* Tap Dance */
// Tap Dance functions
void tap_caps(tap_dance_state_t *state, void *user_data) {
    switch (state->count) {
        case 1:
            caps_word_toggle();
            break;
        case 2:
            tap_code(KC_CAPS);
            break;
    }
}

// Tap Dance definitions
/* Return an integer that corresponds to what kind of tap dance should be executed.
 *
 * How to figure out tap dance state: interrupted and pressed.
 *
 * Interrupted: If the state of a dance is "interrupted", that means that another key has been hit
 *  under the tapping term. This is typically indicitive that you are trying to "tap" the key.
 *
 * Pressed: Whether or not the key is still being pressed. If this value is true, that means the tapping term
 *  has ended, but the key is still being pressed down. This generally means the key is being "held".
 *
 * One thing that is currenlty not possible with qmk software in regards to tap dance is to mimic the "permissive hold"
 *  feature. In general, advanced tap dances do not work well if they are used with commonly typed letters.
 *  For example "A". Tap dances are best used on non-letter keys that are not hit while typing letters.
 *
 * Good places to put an advanced tap dance:
 *  z,q,x,j,k,v,b, any function key, home/end, comma, semi-colon
 *
 * Criteria for "good placement" of a tap dance key:
 *  Not a key that is hit frequently in a sentence
 *  Not a key that is used frequently to double tap, for example 'tab' is often double tapped in a terminal, or
 *    in a web form. So 'tab' would be a poor choice for a tap dance.
 *  Letters used in common words as a double. For example 'p' in 'pepper'. If a tap dance function existed on the
 *    letter 'p', the word 'pepper' would be quite frustating to type.
 *
 * For the third point, there does exist the 'TD_DOUBLE_SINGLE_TAP', however this is not fully tested
 *
 */
td_state_t cur_dance(tap_dance_state_t *state) {
    if (state->count == 1) {
        if (state->interrupted || !state->pressed) return TD_SINGLE_TAP;
        // Key has not been interrupted, but the key is still held. Means you want to send a 'HOLD'.
        else return TD_SINGLE_HOLD;
    }
    else if (state->count == 2) {
        if (!state->pressed) return TD_DOUBLE_TAP;
        else return TD_DOUBLE_HOLD;
    }

    // Assumes no one is trying to type the same letter three times (at least not quickly).
    // If your tap dance key is 'KC_W', and you want to type "www." quickly - then you will need to add
    // an exception here to return a 'TD_TRIPLE_SINGLE_TAP', and define that enum just like 'TD_DOUBLE_SINGLE_TAP'
    else if (state->count == 3) {
        if (!state->pressed) return TD_TRIPLE_TAP;
        else return TD_TRIPLE_HOLD;
    }
    else if (state->count == 4) {
        if (!state->pressed) return TD_QUADRUPLE_TAP;
        else return TD_QUADRUPLE_HOLD;
    }
    else return TD_UNKNOWN;
}

// Create an instance of 'td_tap_t' for the 'ent' tap dance.
static td_tap_t modtap_state = {
    .is_press_action = true,
    .state = TD_NONE
};

void mod_finished(tap_dance_state_t *state, void *user_data) {
    modtap_state.state = cur_dance(state);
    switch (modtap_state.state) {
        case TD_SINGLE_TAP:     register_code(KC_ESC);  break;
        case TD_SINGLE_HOLD:    layer_on(_EXTEND);      break;
        case TD_DOUBLE_TAP:     layer_invert(_EXTEND);  break;
        case TD_DOUBLE_HOLD:    register_code(KC_LCTL); break;
        case TD_TRIPLE_TAP:     register_code(KC_ESC);  break;
        case TD_TRIPLE_HOLD:    register_code(KC_LALT); break;
        case TD_QUADRUPLE_TAP:  register_code(KC_ESC);  break;
        case TD_QUADRUPLE_HOLD: register_code(KC_LGUI); break;
        default: break;
    }
}

void mod_reset(tap_dance_state_t *state, void *user_data) {
    switch (modtap_state.state) {
        case TD_SINGLE_TAP:     unregister_code(KC_ESC);  break;
        case TD_SINGLE_HOLD:    layer_off(_EXTEND); layer_off(_MOUSE); break;
        case TD_DOUBLE_TAP:                               break;
        case TD_DOUBLE_HOLD:    unregister_code(KC_LCTL); break;
        case TD_TRIPLE_TAP:     unregister_code(KC_ESC);  break;
        case TD_TRIPLE_HOLD:    unregister_code(KC_LALT); break;
        case TD_QUADRUPLE_TAP:  unregister_code(KC_ESC);  break;
        case TD_QUADRUPLE_HOLD: unregister_code(KC_LGUI); break;
        default: break;
    }
    modtap_state.state = TD_NONE;
}

tap_dance_action_t tap_dance_actions[] = {
    // Tap once for Escape, twice for Caps Lock
    [TD_CAPS] = ACTION_TAP_DANCE_FN(tap_caps),
    [TD_MOD] =  ACTION_TAP_DANCE_FN_ADVANCED(NULL, mod_finished, mod_reset),
};
/*
uint16_t get_tapping_term(uint16_t keycode, keyrecord_t *record) {
    switch (keycode) {
        case QK_TAP_DANCE ... QK_TAP_DANCE_MAX:
            return TAPPING_TERM;
        default:
            return TAPPING_TERM;
    }
}
*/

/* Callum Oneshots */
bool is_oneshot_cancel_key(uint16_t keycode) {
    switch (keycode) {
    case LT_SFT:
    case LT_SYM:
    case LT_EXTEND:
        return true;
    default:
        return false;
    }
}

bool is_oneshot_ignored_key(uint16_t keycode) {
    switch (keycode) {
    /* Thumb Layers */
    case LT_SFT:
    case LT_SYM:
    case LT_EXTEND:
    /* Thumb Mods */
    case KC_LSFT:
    case KC_LCTL:
    case KC_LALT:
    case KC_LGUI:
    /* One Shot Mods */
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

void update_oneshot_layer(
    oneshot_state *state,
    uint16_t keycode,
    keyrecord_t *record
) {
    if (record->event.pressed) {
        switch(*state){
            case os_up_queued:
                if (!is_oneshot_ignored_key(keycode)) {
                    *state = os_up_unqueued;
                    clear_oneshot_layer_state(ONESHOT_PRESSED);
                }
                break;
            default:
                break;
        }
    }
}

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    /* Sentence Case */
    if (!process_sentence_case(keycode, record)) { return false; }
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
        case LT_SFT:
            /* Layer-tap Hold/One-shot implementation
            if (record->event.pressed && !record->tap.count) {
                layer_on(_SHIFT); // Hold to go to SHIFT layer
            }
            else if (record->event.pressed) {
                set_oneshot_layer(_SHIFT, ONESHOT_START); // Tap to go to SHIFT layer (OSL)
                os_lsft_state = os_up_queued;
            }
            else {
                switch(os_lsft_state){
                    case os_up_unqueued:
                        layer_off(_SHIFT);
                        break;
                    default:
                        break;
                }
            }
            */
            if (record->event.pressed && !record->tap.count) {
                layer_on(_SHIFT); // Hold to go to SHIFT layer
            }
            else {
                layer_off(_SHIFT);
            }
            update_tri_layer(_SHIFT, _SYM, _NUM);
            return true;
        case LT_SYM:
            if (record->event.pressed && !record->tap.count) {
                layer_on(_SYM); // Hold to go to SYM layer
            }
            else {
                layer_off(_SYM);
            }
            update_tri_layer(_SHIFT, _SYM, _NUM);
            return true;
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
        /* Magic Keys */
        case MAG_1:
            if (record->event.pressed) {
                process_magic_key_1(get_last_keycode(), get_last_mods());
            }
            return false;
        case MAG_2:
            if (record->event.pressed) {
                process_magic_key_2(get_last_keycode(), get_last_mods());
            }
            return false;
        case MAG_3:
            if (record->event.pressed) {
                process_magic_key_3(get_last_keycode(), get_last_mods());
            }
            return false;
        case MAG_4:
            if (record->event.pressed) {
                process_magic_key_4(get_last_keycode(), get_last_mods());
            }
            return false;
        /* Toggle Sentence Case provided by Pascal Getreuer */
        case SENTENCE:
            if (record->event.pressed) {
                sentence_case_toggle();
            }
            else {

            }
            return false;
    }
    return true;
}
