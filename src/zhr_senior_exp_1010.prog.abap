REPORT zhr_senior_exp_1010.

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

  gv_filename = sy-datum && '_SENIOR_1010.csv'.

  gv_header = 'TABORG;CODLOC;LOCPAI;NOMLOC;DATCRI;DATEXT'.

*---------------------------------------------------------------------*
* Seleção OM (Locais)
*---------------------------------------------------------------------*

  SELECT
    orgeh,
    orgtx,
    begda,
    endda
  INTO TABLE @DATA(gt_org)
  FROM t527x
  WHERE endda >= @sy-datum.

*---------------------------------------------------------------------*
* Buscar relacionamento pai (HRP1001)
*---------------------------------------------------------------------*

  SELECT
    objid,     " filho
    sobid      " pai
  INTO TABLE @DATA(gt_rel)
  FROM hrp1001
  WHERE plvar = '01'
    AND otype = 'O'
    AND rsign = 'B'
    AND relat = '002'   " pertence a
    AND endda >= @sy-datum.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_datcri TYPE char10,
    lv_datext TYPE char10,
    lv_pai    TYPE string.

  LOOP AT gt_org ASSIGNING FIELD-SYMBOL(<fs_org>).

*---------------------------------------------------------------------*
* Data
*---------------------------------------------------------------------*

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_org>-begda
      CHANGING lv_datcri.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_org>-endda
      CHANGING lv_datext.

*---------------------------------------------------------------------*
* Buscar pai
*---------------------------------------------------------------------*

    CLEAR lv_pai.

    READ TABLE gt_rel ASSIGNING FIELD-SYMBOL(<fs_rel>)
      WITH KEY objid = <fs_org>-orgeh.

    IF sy-subrc = 0.
      lv_pai = <fs_rel>-sobid.
    ENDIF.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      '1'                    && ';' && " TABORG (fixo)
      <fs_org>-orgeh         && ';' && " CODLOC
      lv_pai                 && ';' && " LOCPAI
      <fs_org>-orgtx         && ';' && " NOMLOC
      lv_datcri              && ';' && " DATCRI
      lv_datext.                         " DATEXT

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
