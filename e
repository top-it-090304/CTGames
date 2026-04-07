[1mdiff --git a/Materials/game.gd b/Materials/game.gd[m
[1mindex f498b3f..7f8f042 100644[m
[1m--- a/Materials/game.gd[m
[1m+++ b/Materials/game.gd[m
[36m@@ -22,9 +22,6 @@[m [mvar slot_test_console: Panel[m
 var win_popup_tween: Tween[m
 var cam_tween: Tween[m
 [m
[31m-var rotate_left := false[m
[31m-var rotate_right := false[m
[31m-var rotation_speed := 2.0[m
 const PIXEL_FONT: FontFile = preload("res://textures/pixeloidsans/PixeloidSans.ttf")[m
 var _money_base_pos := Vector2.ZERO[m
 var _spins_base_pos := Vector2.ZERO[m
[36m@@ -783,24 +780,3 @@[m [mfunc _format_money(value: int) -> String:[m
 			out = "." + out[m
 			count = 0[m
 	return out[m
[31m-[m
[31m-[m
[31m-func _on_left_button_down():[m
[31m-	rotate_left = true[m
[31m-[m
[31m-func _on_left_button_up():[m
[31m-	rotate_left = false[m
[31m-[m
[31m-func _on_right_button_down():[m
[31m-	rotate_right = true[m
[31m-[m
[31m-func _on_right_button_up():[m
[31m-	rotate_right = false[m
[31m-[m
[31m-func _process(delta):[m
[31m-	_update_hud_shake()[m
[31m-	_update_ready_button_visibility()[m
[31m-	if rotate_left:[m
[31m-		$Camera3D.rotate_y(-rotation_speed * delta)[m
[31m-	if rotate_right:[m
[31m-		$Camera3D.rotate_y(rotation_speed * delta)[m
[1mdiff --git a/Materials/game.tscn b/Materials/game.tscn[m
[1mindex 3d331c2..ce0711a 100644[m
[1m--- a/Materials/game.tscn[m
[1m+++ b/Materials/game.tscn[m
[36m@@ -29,8 +29,6 @@[m
 [ext_resource type="Script" uid="uid://8i7nkpkaqjde" path="res://Materials/buy_button.gd" id="27_mv4lk"][m
 [ext_resource type="Script" uid="uid://b63cn3a1hjomo" path="res://Materials/close_button.gd" id="28_oat0n"][m
 [ext_resource type="PackedScene" uid="uid://cjrwowv1y66vk" path="res://Objects/Wine Glass.glb" id="28_tn84i"][m
[31m-[ext_resource type="Texture2D" uid="uid://ecp53pl5jbcr" path="res://Objects/Стрелка1-no-bg-preview (carve.photos).png" id="30_xkq3k"][m
[31m-[ext_resource type="Texture2D" uid="uid://db8jtlbskokpt" path="res://Objects/Стрелка2-no-bg-preview (carve.photos).png" id="31_4gd6a"][m
 [ext_resource type="Script" uid="uid://01du5b4o2mbh" path="res://Materials/ready_button.gd" id="31_uasde"][m
 [ext_resource type="Script" uid="uid://wka1rk8u27jb" path="res://Materials/totem_shop.gd" id="32_54luh"][m
 [ext_resource type="Script" uid="uid://duhnls4b655nw" path="res://Materials/win_sequence_layer.gd" id="33_8k356"][m
[36m@@ -38,7 +36,7 @@[m
 [ext_resource type="Script" uid="uid://cfv8k0p4oub4j" path="res://totem_item.gd" id="42_ln6k1"][m
 [ext_resource type="PackedScene" uid="uid://crpb7yejlgx2y" path="res://Objects/shkaf.glb" id="43_ln6k1"][m
 [ext_resource type="Script" uid="uid://bcwex0y21usjj" path="res://Materials/pause_layer.gd" id="46_nt7fw"][m
[31m-[ext_resource type="PackedScene" uid="uid://dg2fvorj2edl5" path="res://Objects/bell.glb" id="46_yy33s"][m
[32m+[m[32m[ext_resource type="PackedScene" uid="uid://dg2fvorj2edl5" path="res://Objects/Bell.glb" id="46_yy33s"][m
 [ext_resource type="Script" uid="uid://dpour1uu533ad" path="res://Materials/totem_item.gd" id="47_gs0kc"][m
 [ext_resource type="PackedScene" uid="uid://brucrkwkxm78d" path="res://Objects/fluorescent_lamplight_-_4096px2.glb" id="48_gwlxx"][m
 [ext_resource type="PackedScene" uid="uid://dacacdw04hvct" path="res://back/lucky_7.tscn" id="48_id0qs"][m
[36m@@ -53,7 +51,7 @@[m
 [ext_resource type="PackedScene" uid="uid://lumo42tfv36o" path="res://diamond.glb" id="54_omno6"][m
 [ext_resource type="Script" uid="uid://blwdsgmrq2ro2" path="res://Materials/slot_ui.gd" id="54_slotui"][m
 [ext_resource type="PackedScene" uid="uid://boxkh4qi1enro" path="res://lemon.glb" id="55_omno6"][m
[31m-[ext_resource type="Script" path="res://Materials/slot_visual_stage.gd" id="56_visualstage"][m
[32m+[m[32m[ext_resource type="Script" uid="uid://dgi1xre8rxvph" path="res://Materials/slot_visual_stage.gd" id="56_visualstage"][m
 [m
 [sub_resource type="StandardMaterial3D" id="StandardMaterial3D_7l2bl"][m
 albedo_texture = ExtResource("2_62l5a")[m
[36m@@ -102,36 +100,6 @@[m [malbedo_texture = ExtResource("49_p4b4j")[m
 [sub_resource type="StandardMaterial3D" id="StandardMaterial3D_nxyih"][m
 albedo_texture = ExtResource("49_p4b4j")[m
 [m
[31m-[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_p4b4j"][m
[31m-bg_color = Color(0, 0, 0, 1)[m
[31m-border_width_left = 1[m
[31m-border_width_right = 1[m
[31m-border_color = Color(1, 0.45, 0.05, 0.35)[m
[31m-[m
[31m-[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_omno6"][m
[31m-bg_color = Color(0, 0, 0, 1)[m
[31m-border_width_left = 1[m
[31m-border_width_right = 1[m
[31m-border_color = Color(1, 0.45, 0.05, 0.35)[m
[31m-[m
[31m-[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_k6p7f"][m
[31m-bg_color = Color(0, 0, 0, 1)[m
[31m-border_width_left = 1[m
[31m-border_width_right = 1[m
[31m-border_color = Color(1, 0.45, 0.05, 0.35)[m
[31m-[m
[31m-[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_2c4sm"][m
[31m-bg_color = Color(0, 0, 0, 1)[m
[31m-border_width_left = 1[m
[31m-border_width_right = 1[m
[31m-border_color = Color(1, 0.45, 0.05, 0.35)[m
[31m-[m
[31m-[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_syuwj"][m
[31m-bg_color = Color(0, 0, 0, 1)[m
[31m-border_width_left = 1[m
[31m-border_width_right = 1[m
[31m-border_color = Color(1, 0.45, 0.05, 0.35)[m
[31m-[m
 [sub_resource type="StyleBoxFlat" id="StyleBoxFlat_yci1l"][m
 bg_color = Color(0, 0, 0, 1)[m
 border_width_left = 1[m
[36m@@ -541,12 +509,12 @@[m [msymbols = Array[Texture2D]([ExtResource("10_7l2bl"), ExtResource("6_g7uyw"), Ext[m
 weights = Array[float]([20.0, 20.0, 15.0, 15.0, 11.5, 11.5, 7.0])[m
 reels_row_path = NodePath("SlotReels")[m
 label_path = NodePath("StatusLabel")[m
[31m-visual_stage_path = NodePath("CloverStage")[m
 [m
 [node name="CloverStage" type="Control" parent="SubViewport/SlotUI" unique_id=1246282959][m
[31m-layout_mode = 0[m
[31m-offset_right = 40.0[m
[31m-offset_bottom = 40.0[m
[32m+[m[32mz_index = 5[m
[32m+[m[32manchors_preset = 0[m
[32m+[m[32manchor_right = 1.0[m
[32m+[m[32manchor_bottom = 1.0[m
 mouse_filter = 2[m
 script = ExtResource("56_visualstage")[m
 [m
[36m@@ -833,16 +801,6 @@[m [mtransform = Transform3D(-0.26302075, 0, 0.056195863, 0, 0.2836941, 0, -0.0512451[m
 [node name="Root Scene3" parent="." unique_id=751196611 instance=ExtResource("28_tn84i")][m
 transform = Transform3D(3.3191843, 0, 0, 0, 0.29119322, 3.0565648, 0, -3.0475721, 0.29205245, -3.7615168, 1.1665496, -1.817327)[m
 [m
[31m-[node name="Стрелка1NoBgPreview(carve_photos)" type="Sprite2D" parent="." unique_id=429006024][m
[31m-position = Vector2(1063, 565.5)[m
[31m-scale = Vector2(1.348485, 1.3865546)[m
[31m-texture = ExtResource("30_xkq3k")[m
[31m-[m
[31m-[node name="Стрелка2NoBgPreview(carve_photos)" type="Sprite2D" parent="." unique_id=824532741][m
[31m-position = Vector2(90.49999, 565.5)[m
[31m-scale = Vector2(1.3923078, 1.3865548)[m
[31m-texture = ExtResource("31_4gd6a")[m
[31m-[m
 [node name="TotemShop" type="Node3D" parent="." unique_id=1463476390][m
 transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.49418712, 0.53030854, 0)[m
 script = ExtResource("32_54luh")[m
[1mdiff --git a/Objects/Bell.glb.import b/Objects/Bell.glb.import[m
[1mindex f125b51..4b83afc 100644[m
[1m--- a/Objects/Bell.glb.import[m
[1m+++ b/Objects/Bell.glb.import[m
[36m@@ -4,12 +4,12 @@[m [mimporter="scene"[m
 importer_version=1[m
 type="PackedScene"[m
 uid="uid://dg2fvorj2edl5"[m
[31m-path="res://.godot/imported/bell.glb-325c8d8a3b3f812ce9a53146054b5367.scn"[m
[32m+[m[32mpath="res://.godot/imported/Bell.glb-99797fcce02e447c79cc85aef2a339a1.scn"[m
 [m
 [deps][m
 [m
[31m-source_file="res://Objects/bell.glb"[m
[31m-dest_files=["res://.godot/imported/bell.glb-325c8d8a3b3f812ce9a53146054b5367.scn"][m
[32m+[m[32msource_file="res://Objects/Bell.glb"[m
[32m+[m[32mdest_files=["res://.godot/imported/Bell.glb-99797fcce02e447c79cc85aef2a339a1.scn"][m
 [m
 [params][m
 [m

                   SSUUMMMMAARRYY OOFF LLEESSSS CCOOMMMMAANNDDSS

      Commands marked with * may be preceded by a number, _N.
      Notes in parentheses indicate the behavior if _N is given.
      A key preceded by a caret indicates the Ctrl key; thus ^K is ctrl-K.

  h  H                 Display this help.
  q  :q  Q  :Q  ZZ     Exit.
 ---------------------------------------------------------------------------

                           MMOOVVIINNGG

  e  ^E  j  ^N  CR  *  Forward  one line   (or _N lines).
  y  ^Y  k  ^K  ^P  *  Backward one line   (or _N lines).
  ESC-j             *  Forward  one file line (or _N file lines).
  ESC-k             *  Backward one file line (or _N file lines).
  f  ^F  ^V  SPACE  *  Forward  one window (or _N lines).
  b  ^B  ESC-v      *  Backward one window (or _N lines).
  z                 *  Forward  one window (and set window to _N).
  w                 *  Backward one window (and set window to _N).
  ESC-SPACE         *  Forward  one window, but don't stop at end-of-file.
  ESC-b             *  Backward one window, but don't stop at beginning-of-file.
  d  ^D             *  Forward  one half-window (and set half-window to _N).
  u  ^U             *  Backward one half-window (and set half-window to _N).
  ESC-)  RightArrow *  Right one half screen width (or _N positions).
  ESC-(  LeftArrow  *  Left  one half screen width (or _N positions).
  ESC-}  ^RightArrow   Right to last column displayed.
  ESC-{  ^LeftArrow    Left  to first column.
  F                    Forward forever; like "tail -f".
  ESC-F                Like F but stop when search pattern is found.
  r  ^R  ^L            Repaint screen.
  R                    Repaint screen, discarding buffered input.
        ---------------------------------------------------
        Default "window" is the screen height.
        Default "half-window" is half of the screen height.
 ---------------------------------------------------------------------------

                          SSEEAARRCCHHIINNGG

  /_p_a_t_t_e_r_n          *  Search forward for (_N-th) matching line.
  ?_p_a_t_t_e_r_n          *  Search backward for (_N-th) matching line.
  n                 *  Repeat previous search (for _N-th occurrence).
  N                 *  Repeat previous search in reverse direction.
  ESC-n             *  Repeat previous search, spanning files.
  ESC-N             *  Repeat previous search, reverse dir. & spanning files.
  ^O^N  ^On         *  Search forward for (_N-th) OSC8 hyperlink.
  ^O^P  ^Op         *  Search backward for (_N-th) OSC8 hyperlink.
  ^O^L  ^Ol            Jump to the currently selected OSC8 hyperlink.
  ESC-u                Undo (toggle) search highlighting.
  ESC-U                Clear search highlighting.
  &_p_a_t_t_e_r_n          *  Display only matching lines.
        ---------------------------------------------------
		Search is case-sensitive unless changed with -i or -I.
        A search pattern may begin with one or more of:
        ^N or !  Search for NON-matching lines.
        ^E or *  Search multiple files (pass thru END OF FILE).
        ^F or @  Start search at FIRST file (for /) or last file (for ?).
        ^K       Highlight matches, but don't move (KEEP position).
        ^R       Don't use REGULAR EXPRESSIONS.
        ^S _n     Search for match in _n-th parenthesized subpattern.
        ^W       WRAP search if no match found.
        ^L       Enter next character literally into pattern.
 ---------------------------------------------------------------------------

                           JJUUMMPPIINNGG

  g  <  ESC-<       *  Go to first line in file (or line _N).
  G  >  ESC->       *  Go to last line in file (or line _N).
  p  %              *  Go to beginning of file (or _N percent into file).
  t                 *  Go to the (_N-th) next tag.
  T                 *  Go to the (_N-th) previous tag.
  {  (  [           *  Find close bracket } ) ].
  }  )  ]           *  Find open bracket { ( [.
  ESC-^F _<_c_1_> _<_c_2_>  *  Find close bracket _<_c_2_>.
  ESC-^B _<_c_1_> _<_c_2_>  *  Find open bracket _<_c_1_>.
        ---------------------------------------------------
        Each "find close bracket" command goes forward to the close bracket 
          matching the (_N-th) open bracket in the top line.
        Each "find open bracket" command goes backward to the open bracket 
          matching the (_N-th) close bracket in the bottom line.

  m_<_l_e_t_t_e_r_>            Mark the current top line with <letter>.
  M_<_l_e_t_t_e_r_>            Mark the current bottom line with <letter>.
  '_<_l_e_t_t_e_r_>            Go to a previously marked position.
  ''                   Go to the previous position.
  ^X^X                 Same as '.
  ESC-m_<_l_e_t_t_e_r_>        Clear a mark.
        ---------------------------------------------------
        A mark is any upper-case or lower-case letter.
        Certain marks are predefined:
             ^  means  beginning of the file
             $  means  end of the file
 ---------------------------------------------------------------------------

                        CCHHAANNGGIINNGG FFIILLEESS

  :e [_f_i_l_e]            Examine a new file.
  ^X^V                 Same as :e.
  :n                *  Examine the (_N-th) next file from the command line.
  :p                *  Examine the (_N-th) previous file from the command line.
  :x                *  Examine the first (or _N-th) file from the command line.
  ^O^O                 Open the currently selected OSC8 hyperlink.
  :d                   Delete the current file from the command line list.
  =  ^G  :f            Print current file name.
 ---------------------------------------------------------------------------

                    MMIISSCCEELLLLAANNEEOOUUSS CCOOMMMMAANNDDSS

  -_<_f_l_a_g_>              Toggle a command line option [see OPTIONS below].
  --_<_n_a_m_e_>             Toggle a command line option, by name.
  __<_f_l_a_g_>              Display the setting of a command line option.
  ___<_n_a_m_e_>             Display the setting of an option, by name.
  +_c_m_d                 Execute the less cmd each time a new file is examined.

  !_c_o_m_m_a_n_d             Execute the shell command with $SHELL.
  #_c_o_m_m_a_n_d             Execute the shell command, expanded like a prompt.
  |XX_c_o_m_m_a_n_d            Pipe file between current pos & mark XX to shell command.
  s _f_i_l_e               Save input to a file.
  v                    Edit the current file with $VISUAL or $EDITOR.
  V                    Print version number of "less".
 ---------------------------------------------------------------------------

                           OOPPTTIIOONNSS

        Most options may be changed either on the command line,
        or from within less by using the - or -- command.
        Options may be given in one of two forms: either a single
        character preceded by a -, or a name preceded by --.

  -?  ........  --help
                  Display help (from command line).
  -a  ........  --search-skip-screen
                  Search skips current screen.
  -A  ........  --SEARCH-SKIP-SCREEN
                  Search starts just after target line.
  -b [_N]  ....  --buffers=[_N]
                  Number of buffers.
  -B  ........  --auto-buffers
                  Don't automatically allocate buffers for pipes.
  -c  ........  --clear-screen
                  Repaint by clearing rather than scrolling.
  -d  ........  --dumb
                  Dumb terminal.
  -D xx_c_o_l_o_r  .  --color=xx_c_o_l_o_r
                  Set screen colors.
  -e  -E  ....  --quit-at-eof  --QUIT-AT-EOF
                  Quit at end of file.
  -f  ........  --force
                  Force open non-regular files.
  -F  ........  --quit-if-one-screen
                  Quit if entire file fits on first screen.
  -g  ........  --hilite-search
                  Highlight only last match for searches.
  -G  ........  --HILITE-SEARCH
                  Don't highlight any matches for searches.
  -h [_N]  ....  --max-back-scroll=[_N]
                  Backward scroll limit.
  -i  ........  --ignore-case
                  Ignore case in searches that do not contain uppercase.
  -I  ........  --IGNORE-CASE
                  Ignore case in all searches.
  -j [_N]  ....  --jump-target=[_N]
                  Screen position of target lines.
  -J  ........  --status-column
                  Display a status column at left edge of screen.
  -k _f_i_l_e  ...  --lesskey-file=_f_i_l_e
                  Use a compiled lesskey file.
  -K  ........  --quit-on-intr
                  Exit less in response to ctrl-C.
  -L  ........  --no-lessopen
                  Ignore the LESSOPEN environment variable.
  -m  -M  ....  --long-prompt  --LONG-PROMPT
                  Set prompt style.
  -n .........  --line-numbers
                  Suppress line numbers in prompts and messages.
  -N .........  --LINE-NUMBERS
                  Display line number at start of each line.
  -o [_f_i_l_e] ..  --log-file=[_f_i_l_e]
                  Copy to log file (standard input only).
  -O [_f_i_l_e] ..  --LOG-FILE=[_f_i_l_e]
                  Copy to log file (unconditionally overwrite).
  -p _p_a_t_t_e_r_n .  --pattern=[_p_a_t_t_e_r_n]
                  Start at pattern (from command line).
  -P [_p_r_o_m_p_t]   --prompt=[_p_r_o_m_p_t]
                  Define new prompt.
  -q  -Q  ....  --quiet  --QUIET  --silent --SILENT
                  Quiet the terminal bell.
  -r  -R  ....  --raw-control-chars  --RAW-CONTROL-CHARS
                  Output "raw" control characters.
  -s  ........  --squeeze-blank-lines
                  Squeeze multiple blank lines.
  -S  ........  --chop-long-lines
                  Chop (truncate) long lines rather than wrapping.
  -t _t_a_g  ....  --tag=[_t_a_g]
                  Find a tag.
  -T [_t_a_g_s_f_i_l_e] --tag-file=[_t_a_g_s_f_i_l_e]
                  Use an alternate tags file.
  -u  -U  ....  --underline-special  --UNDERLINE-SPECIAL
                  Change handling of backspaces, tabs and carriage returns.
  -V  ........  --version
                  Display the version number of "less".
  -w  ........  --hilite-unread
                  Highlight first new line after forward-screen.
  -W  ........  --HILITE-UNREAD
                  Highlight first new line after any forward movement.
  -x [_N[,...]]  --tabs=[_N[,...]]
                  Set tab stops.
  -X  ........  --no-init
                  Don't use termcap init/deinit strings.
  -y [_N]  ....  --max-forw-scroll=[_N]
                  Forward scroll limit.
  -z [_N]  ....  --window=[_N]
                  Set size of window.
  -" [_c[_c]]  .  --quotes=[_c[_c]]
                  Set shell quote characters.
  -~  ........  --tilde
                  Don't display tildes after end of file.
  -# [_N]  ....  --shift=[_N]
                  Set horizontal scroll amount (0 = one half screen width).

                --exit-follow-on-close
                  Exit F command on a pipe when writer closes pipe.
                --file-size
                  Automatically determine the size of the input file.
                --follow-name
                  The F command changes files if the input file is renamed.
                --form-feed
                  Stop scrolling when a form feed character is reached.
                --header=[_L[,_C[,_N]]]
                  Use _L lines (starting at line _N) and _C columns as headers.
                --incsearch
                  Search file as each pattern character is typed in.
                --intr=[_C]
                  Use _C instead of ^X to interrupt a read.
                --lesskey-context=_t_e_x_t
                  Use lesskey source file contents.
                --lesskey-src=_f_i_l_e
                  Use a lesskey source file.
                --line-num-width=[_N]
                  Set the width of the -N line number field to _N characters.
                --match-shift=[_N]
                  Show at least _N characters to the left of a search match.
                --modelines=[_N]
                  Read _N lines from the input file and look for vim modelines.
                --mouse
                  Enable mouse input.
                --no-edit-warn
                  Don't warn when using v command on a file opened via LESSOPEN.
                --no-keypad
                  Don't send termcap keypad init/deinit strings.
                --no-histdups
                  Remove duplicates from command history.
                --no-number-headers
                  Don't give line numbers to header lines.
                --no-paste
                  Ignore pasted input.
                --no-search-header-lines
                  Searches do not include header lines.
                --no-search-header-columns
                  Searches do not include header columns.
                --no-search-headers
                  Searches do not include header lines or columns.
                --no-vbell
                  Disable the terminal's visual bell.
                --redraw-on-quit
                  Redraw final screen when quitting.
                --rscroll=[_C]
                  Set the character used to mark truncated lines.
                --save-marks
                  Retain marks across invocations of less.
                --search-options=[EFKNRW-]
                  Set default options for every search.
                --show-preproc-errors
                  Display a message if preprocessor exits with an error status.
                --proc-backspace
                  Process backspaces for bold/underline.
                --PROC-BACKSPACE
                  Treat backspaces as control characters.
                --proc-return
                  Delete carriage returns before newline.
                --PROC-RETURN
                  Treat carriage returns as control characters.
                --proc-tab
                  Expand tabs to spaces.
                --PROC-TAB
                  Treat tabs as control characters.
                --status-col-width=[_N]
                  Set the width of the -J status column to _N characters.
                --status-line
                  Highlight or color the entire line containing a mark.
                --use-backslash
                  Subsequent options use backslash as escape char.
                --use-color
                  Enables colored text.
                --wheel-lines=[_N]
                  Each click of the mouse wheel moves _N lines.
                --wordwrap
                  Wrap lines at spaces.


 ---------------------------------------------------------------------------

                          LLIINNEE EEDDIITTIINNGG

        These keys can be used to edit text being entered 
        on the "command line" at the bottom of the screen.

 RightArrow ..................... ESC-l ... Move cursor right one character.
 LeftArrow ...................... ESC-h ... Move cursor left one character.
 ctrl-RightArrow  ESC-RightArrow  ESC-w ... Move cursor right one word.
 ctrl-LeftArrow   ESC-LeftArrow   ESC-b ... Move cursor left one word.
 HOME ........................... ESC-0 ... Move cursor to start of line.
 END ............................ ESC-$ ... Move cursor to end of line.
 BACKSPACE ................................ Delete char to left of cursor.
 DELETE ......................... ESC-x ... Delete char under cursor.
 ctrl-BACKSPACE   ESC-BACKSPACE ........... Delete word to left of cursor.
 ctrl-DELETE .... ESC-DELETE .... ESC-X ... Delete word under cursor.
 ctrl-U ......... ESC (MS-DOS only) ....... Delete entire line.
 UpArrow ........................ ESC-k ... Retrieve previous command line.
 DownArrow ...................... ESC-j ... Retrieve next command line.
 TAB ...................................... Complete filename & cycle.
 SHIFT-TAB ...................... ESC-TAB   Complete filename & reverse cycle.
 ctrl-L ................................... Complete filename, list all.
