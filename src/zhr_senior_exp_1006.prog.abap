REPORT zhr_export_senior_1006.

PARAMETERS: p_file TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f_selecionar_arquivo.

START-OF-SELECTION.

  PERFORM f_exportar_dados.

*---------------------------------------------------------------------*

*---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA:
    gv_filename TYPE string,
    gv_header   TYPE string,
    gv_line     TYPE string,
    gt_file     TYPE STANDARD TABLE OF string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = sy-datum && '_SENIOR_1006.csv'.

  gv_header = 'CODMOT;NOMMOT;TIPMOT;MTVALT;TPOMVT'.

*---------------------------------------------------------------------*
* SeleÃ§Ã£o de motivos (T530)
*---------------------------------------------------------------------*

  SELECT
    massg,   " CÃ³digo motivo
    mgtxt,   " DescriÃ§Ã£o
    massn    " Tipo movimentaÃ§Ã£o
  INTO TABLE @DATA(gt_motivos)
  FROM t530t.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_tipmot TYPE c LENGTH 1,
    lv_mtvalt TYPE c LENGTH 1,
    lv_tpomvt TYPE c LENGTH 1.

  LOOP AT gt_motivos ASSIGNING FIELD-SYMBOL(<fs_mot>).

*---------------------------------------------------------------------*
* TIPMOT - Lista LTipMot
*---------------------------------------------------------------------*

    PERFORM f_conv_tipmot IN PROGRAM zhr_export_senior
      USING <fs_mot>-massg
      CHANGING lv_tipmot.

    IF lv_tipmot IS INITIAL.
      lv_tipmot = 'E'. " fallback
    ENDIF.

*---------------------------------------------------------------------*
* MTVALT - Lista LMtvAlt
*---------------------------------------------------------------------*

    PERFORM f_conv_mtvalt IN PROGRAM zhr_export_senior
      USING <fs_mot>-massg
      CHANGING lv_mtvalt.

    IF lv_mtvalt IS INITIAL.
      lv_mtvalt = '0'. " fallback
    ENDIF.

*---------------------------------------------------------------------*
* TPOMVT - Lista LTpoMvt
*---------------------------------------------------------------------*

    PERFORM f_conv_tpomvt IN PROGRAM zhr_export_senior
      USING <fs_mot>-massn
      CHANGING lv_tpomvt.

    IF lv_tpomvt IS INITIAL.
      lv_tpomvt = '0'. " fallback
    ENDIF.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_mot>-massg     && ';' && " CODMOT
      <fs_mot>-mgtxt     && ';' && " NOMMOT
      lv_tipmot          && ';' && " TIPMOT
      lv_mtvalt          && ';' && " MTVALT
      lv_tpomvt.                   " TPOMVT

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo USING gv_filename CHANGING gt_file.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.

FORM f_selecionar_arquivo.

  DATA:
    lv_filename TYPE string,
    lv_path     TYPE string,
    lv_fullpath TYPE string.

  CALL METHOD cl_gui_frontend_services=>file_save_dialog
    EXPORTING
      default_extension = 'csv'
    CHANGING
      filename          = lv_filename
      path              = lv_path
      fullpath          = lv_fullpath
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc = 0 AND lv_fullpath IS NOT INITIAL.
    p_file = lv_fullpath.
  ENDIF.

ENDFORM.

FORM f_salvar_arquivo USING pv_filename TYPE string
                     CHANGING pt_file TYPE STANDARD TABLE.

  DATA:
    lv_filename TYPE string,
    lv_path     TYPE string,
    lv_fullpath TYPE string.

  lv_fullpath = p_file.

  IF lv_fullpath IS INITIAL.
    CALL METHOD cl_gui_frontend_services=>file_save_dialog
      EXPORTING
        default_extension = 'csv'
        default_file_name = pv_filename
      CHANGING
        filename          = lv_filename
        path              = lv_path
        fullpath          = lv_fullpath
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4.

    IF sy-subrc <> 0 OR lv_fullpath IS INITIAL.
      MESSAGE 'Selecao de arquivo cancelada.' TYPE 'E'.
    ENDIF.
  ENDIF.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename = lv_fullpath
      filetype = 'ASC'
    TABLES
      data_tab = pt_file
    EXCEPTIONS
      OTHERS   = 1.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao salvar arquivo local.' TYPE 'E'.
  ENDIF.

  p_file = lv_fullpath.

ENDFORM.
