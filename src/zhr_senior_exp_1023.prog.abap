REPORT zhr_senior_exp_1023.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

START-OF-SELECTION.

  PERFORM f_export.

FORM f_export.

  DATA: gv_filename TYPE string,
        gv_header   TYPE string,
        gv_line     TYPE string,
        gt_file     TYPE STANDARD TABLE OF string.

  TYPES: BEGIN OF ty_nat,
           natdes TYPE n LENGTH 2,
           nommat TYPE c LENGTH 20,
         END OF ty_nat.

  DATA gt_nat TYPE STANDARD TABLE OF ty_nat.

  gv_filename = sy-datum && '_SENIOR_1023.csv'.
  gv_header = 'NATDES;NOMMAT'.

  APPEND gv_header TO gt_file.

  APPEND VALUE ty_nat( natdes = '1' nommat = 'MAO DE OBRA DIRETA' ) TO gt_nat.
  APPEND VALUE ty_nat( natdes = '2' nommat = 'MAO DE OBRA INDIRETA' ) TO gt_nat.

  LOOP AT gt_nat ASSIGNING FIELD-SYMBOL(<fs_nat>).

    DATA: lv_natdes TYPE string,
          lv_nommat TYPE string.

    lv_natdes = <fs_nat>-natdes.
    lv_nommat = <fs_nat>-nommat.

    PERFORM f_fit_field USING lv_natdes 2 CHANGING lv_natdes.
    PERFORM f_fit_field USING lv_nommat 20 CHANGING lv_nommat.

    CONCATENATE lv_natdes lv_nommat INTO gv_line SEPARATED BY ';'.
    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1023 gerado:', gv_filename.

ENDFORM.

FORM f_fit_field
  USING    pv_value  TYPE any
           pv_length TYPE i
  CHANGING pv_text   TYPE string.

  pv_text = |{ pv_value }|.
  REPLACE ALL OCCURRENCES OF ';' IN pv_text WITH ','.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN pv_text WITH space.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN pv_text WITH space.
  CONDENSE pv_text.

  IF pv_length > 0
     AND strlen( pv_text ) > pv_length.
    pv_text = pv_text(pv_length).
  ENDIF.

ENDFORM.
