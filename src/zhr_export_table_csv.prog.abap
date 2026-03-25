REPORT zhr_export_table_csv.

PARAMETERS: p_tab  TYPE tabname OBLIGATORY,
            p_date TYPE string LOWER CASE,
            p_file TYPE string LOWER CASE.

DATA: gv_filename TYPE string,
      gv_header   TYPE string,
      gv_count    TYPE i.

DATA: lt_fields TYPE TABLE OF dfies,
      ls_field  TYPE dfies.

DATA lv_cursor TYPE cursor.

FIELD-SYMBOLS:
  <gt_table> TYPE STANDARD TABLE,
  <gs_line>  TYPE any,
  <gv_field> TYPE any.

DATA gr_data TYPE REF TO data.

START-OF-SELECTION.

  PERFORM validate_table.
  PERFORM get_fields.
  PERFORM create_dynamic_table.
  PERFORM build_filename.
  PERFORM build_header.
  PERFORM export_data.

*---------------------------------------------------------------------*
FORM validate_table.

  SELECT SINGLE tabname
    FROM dd02l
    WHERE tabname = @p_tab
    AND tabclass = 'TRANSP'
    INTO @DATA(lv_tab).

  IF sy-subrc <> 0.
    MESSAGE 'Tabela inválida' TYPE 'E'.
  ENDIF.

ENDFORM.

*---------------------------------------------------------------------*
FORM get_fields.

  CALL FUNCTION 'DDIF_FIELDINFO_GET'
    EXPORTING
      tabname        = p_tab
      langu          = sy-langu
      all_types      = 'X'
    TABLES
      dfies_tab      = lt_fields
    EXCEPTIONS
      not_found      = 1
      internal_error = 2
      OTHERS         = 3.

  IF sy-subrc <> 0.
    MESSAGE 'Erro lendo metadados da tabela' TYPE 'E'.
  ENDIF.

  DELETE lt_fields WHERE fieldname IS INITIAL.
  DELETE lt_fields WHERE fieldname = '.INCLUDE'.
  DELETE lt_fields WHERE inttype   = 'h'. " table type / deep type

ENDFORM.

*---------------------------------------------------------------------*
FORM create_dynamic_table.

  DATA lo_struct TYPE REF TO cl_abap_structdescr.
  DATA lo_table  TYPE REF TO cl_abap_tabledescr.

  lo_struct ?= cl_abap_typedescr=>describe_by_name( p_tab ).
  lo_table  = cl_abap_tabledescr=>create( lo_struct ).

  CREATE DATA gr_data TYPE HANDLE lo_table.
  ASSIGN gr_data->* TO <gt_table>.

ENDFORM.

*---------------------------------------------------------------------*
FORM build_filename.

  IF p_file IS INITIAL.
    CONCATENATE '/tmp/'
                p_date '_'
                p_tab
                '.csv'
           INTO gv_filename.
  ELSE.
    CONCATENATE '/temp/' p_file INTO gv_filename.
  ENDIF.

ENDFORM.

*---------------------------------------------------------------------*
FORM build_header.

  CLEAR gv_header.

  LOOP AT lt_fields INTO ls_field.

    IF gv_header IS INITIAL.
      gv_header = ls_field-fieldname.
    ELSE.
      CONCATENATE gv_header
                  ls_field-fieldname
             INTO gv_header
             SEPARATED BY ';'.
    ENDIF.

  ENDLOOP.

ENDFORM.

*---------------------------------------------------------------------*
FORM export_data.

  DATA: lv_line  TYPE string,
        lv_value TYPE string,
        lv_q     TYPE string.

  OPEN DATASET gv_filename
       FOR OUTPUT
       IN TEXT MODE
       ENCODING DEFAULT.

  IF sy-subrc <> 0.
    MESSAGE |Erro abrindo arquivo { gv_filename }| TYPE 'E'.
  ENDIF.

  TRANSFER gv_header TO gv_filename.

  OPEN CURSOR WITH HOLD lv_cursor
    FOR SELECT * FROM (p_tab).

  DO.

    FETCH NEXT CURSOR lv_cursor
      INTO TABLE <gt_table>
      PACKAGE SIZE 10000.

    IF sy-subrc <> 0.
      EXIT.
    ENDIF.

    LOOP AT <gt_table> ASSIGNING <gs_line>.

      CLEAR lv_line.

      LOOP AT lt_fields INTO ls_field.

        ASSIGN COMPONENT ls_field-fieldname
        OF STRUCTURE <gs_line>
        TO <gv_field>.

        IF sy-subrc = 0.

          lv_value = <gv_field>.

          REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN lv_value WITH space.
          REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_value WITH space.
          REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN lv_value WITH space.

          REPLACE ALL OCCURRENCES OF '"'
            IN lv_value WITH '""'.

          CONCATENATE '"' lv_value '"'
                 INTO lv_q.

          IF lv_line IS INITIAL.
            lv_line = lv_q.
          ELSE.
            CONCATENATE lv_line lv_q
              INTO lv_line
              SEPARATED BY ';'.
          ENDIF.

        ENDIF.

      ENDLOOP.

      TRANSFER lv_line TO gv_filename.

      gv_count = gv_count + 1.

    ENDLOOP.

    FREE <gt_table>.

  ENDDO.

  CLOSE CURSOR lv_cursor.
  CLOSE DATASET gv_filename.

*  WRITE: / 'Arquivo:', gv_filename.
*  WRITE: / 'Registros exportados:', gv_count.

ENDFORM.
