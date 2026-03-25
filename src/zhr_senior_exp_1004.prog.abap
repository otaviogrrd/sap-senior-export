REPORT zhr_export_senior_1004.

PARAMETERS: p_file TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f_selecionar_arquivo.

START-OF-SELECTION.  PERFORM f_exportar_dados.

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

  gv_filename = sy-datum && '_SENIOR_1004.csv'.

  gv_header = 'ESTCAR;CODCAR;TITRED;TITCAR;CODCB2;DATCRI;DATEXT;CNHOBR;OCLOBR;CODSIG'.

*---------------------------------------------------------------------*
* SeleÃ§Ã£o de Cargos
*---------------------------------------------------------------------*

  SELECT
    t513~stell,          " CÃ³digo cargo
    t513~begda,
    t513~endda,
    t513s~stltx,         " Texto curto
    t528t~plstx,         " Texto longo
    cbotab~cbo           " CBO

  INTO TABLE @DATA(gt_cargo)

  FROM t513

  LEFT JOIN t513s
    ON t513s~stell = t513~stell
   AND t513s~sprsl = @sy-langu

  LEFT JOIN t528t
    ON t528t~plans = t513~stell
   AND t528t~sprsl = @sy-langu

  LEFT JOIN t7brcb AS cbotab
    ON cbotab~plans = t513~stell

  WHERE t513~endda >= @sy-datum.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_datcri TYPE char10,
    lv_datext TYPE char10.

  LOOP AT gt_cargo ASSIGNING FIELD-SYMBOL(<fs_cargo>).

*---------------------------------------------------------------------*
* Datas
*---------------------------------------------------------------------*

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_cargo>-begda
      CHANGING lv_datcri.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_cargo>-endda
      CHANGING lv_datext.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      '1'               && ';' && " ESTCAR (fixo)
      <fs_cargo>-stell  && ';' && " CODCAR
      <fs_cargo>-stltx  && ';' && " TITRED
      <fs_cargo>-plstx  && ';' && " TITCAR
      <fs_cargo>-cbo    && ';' && " CODCB2
      lv_datcri         && ';' && " DATCRI
      lv_datext         && ';' && " DATEXT
      'N'               && ';' && " CNHOBR (LSimNao)
      'N'               && ';' && " OCLOBR (LSimNao)
      ''.                         " CODSIG

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
      MESSAGE 'Selecao do arquivo cancelada.' TYPE 'E'.
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