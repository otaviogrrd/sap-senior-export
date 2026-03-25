REPORT zhr_senior_exp_1014.

PARAMETERS: p_dir TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_dir.
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

  gv_filename = sy-datum && '_SENIOR_1014.csv'.

  gv_header =
    'ENDUZ;TIPCOL;NUMCAD;DATAFA;HORAFA;DATTER;HORTER;PRVTER;SITAFA;CAUDEM;DIAJUS;OBSAFA;CODDOE;NOMATE;ORGCLA;REGCON;ESTCON;MOTRAI'.

*---------------------------------------------------------------------*
* Sele??o afastamentos
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,
    p2001~begda,
    p2001~beguz,
    p2001~endda,
    p2001~enduz,
    p2001~awart,
    p2001~abwtg
  INTO TABLE @DATA(gt_afast)
  FROM pa0001 AS p1
  INNER JOIN pa2001 AS p2001
    ON p2001~pernr = p1~pernr.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_tipcol TYPE c LENGTH 1,
    lv_datafa TYPE char10,
    lv_datter TYPE char10,
    lv_prvter TYPE char10,
    lv_horafa TYPE string,
    lv_horter TYPE string.

  LOOP AT gt_afast ASSIGNING FIELD-SYMBOL(<fs_afast>).

*---------------------------------------------------------------------*
* Convers?es
*---------------------------------------------------------------------*

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_afast>-persg
      CHANGING lv_tipcol.

*---------------------------------------------------------------------*
* Datas
*---------------------------------------------------------------------*

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_afast>-begda
      CHANGING lv_datafa.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_afast>-endda
      CHANGING lv_datter.

    lv_prvter = lv_datter. " mesma regra

*---------------------------------------------------------------------*
* Hora (hh:mm)
*---------------------------------------------------------------------*

    IF <fs_afast>-beguz IS NOT INITIAL.
      lv_horafa = |{ <fs_afast>-beguz+0(2) }:{ <fs_afast>-beguz+2(2) }|.
    ENDIF.

    IF <fs_afast>-enduz IS NOT INITIAL.
      lv_horter = |{ <fs_afast>-enduz+0(2) }:{ <fs_afast>-enduz+2(2) }|.
    ENDIF.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_afast>-bukrs     && ';' && " ENDUZ
      lv_tipcol            && ';' && " TIPCOL
      <fs_afast>-pernr     && ';' && " NUMCAD
      lv_datafa            && ';' && " DATAFA
      lv_horafa            && ';' && " HORAFA
      lv_datter            && ';' && " DATTER
      lv_horter            && ';' && " HORTER
      lv_prvter            && ';' && " PRVTER
      <fs_afast>-awart     && ';' && " SITAFA
      ''                   && ';' && " CAUDEM
      <fs_afast>-abwtg     && ';' && " DIAJUS
      ''                   && ';' && " OBSAFA
      ''                   && ';' && " CODDOE
      ''                   && ';' && " NOMATE
      ''                   && ';' && " ORGCLA
      ''                   && ';' && " REGCON
      ''                   && ';' && " ESTCON
      ''.                              " MOTRAI

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo USING gv_filename CHANGING gt_file.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.

FORM f_selecionar_arquivo.

  DATA lv_folder TYPE string.

  CALL METHOD cl_gui_frontend_services=>directory_browse
    CHANGING
      selected_folder      = lv_folder
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc = 0 AND lv_folder IS NOT INITIAL.
    p_dir = lv_folder.
  ENDIF.

ENDFORM.

FORM f_salvar_arquivo USING pv_filename TYPE string
                     CHANGING pt_file TYPE STANDARD TABLE.

  DATA:
    lv_folder   TYPE string,
    lv_fullpath TYPE string.
  DATA:
    lv_last TYPE c LENGTH 1,
    lv_len  TYPE i.

  lv_folder = p_dir.

  IF lv_folder IS INITIAL.
    CALL METHOD cl_gui_frontend_services=>directory_browse
      CHANGING
        selected_folder      = lv_folder
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4.

    IF sy-subrc <> 0 OR lv_folder IS INITIAL.
      MESSAGE 'Selecao de diretorio cancelada.' TYPE 'E'.
    ENDIF.
  ENDIF.

  lv_len = strlen( lv_folder ) - 1.
  IF lv_len >= 0.
    lv_last = lv_folder+lv_len(1).
    IF lv_last <> '\' AND lv_last <> '/'.
      CONCATENATE lv_folder '\' INTO lv_folder.
    ENDIF.
  ENDIF.

  CONCATENATE lv_folder pv_filename INTO lv_fullpath.

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

  p_dir = lv_folder.

ENDFORM.
