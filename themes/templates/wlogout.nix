{ lib, theme }:
''
    @define-color overlay ${theme.rgba "base" 0.7};
    @define-color text ${theme.hex "text"};
    @define-color surface0 ${theme.hex "surface0"};
    @define-color base ${theme.hex "base"};
    @define-color accent ${theme.hex theme.selection.accent};
  ''
