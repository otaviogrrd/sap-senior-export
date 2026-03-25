REPORT zhr_export_senior_1008.

PARAMETERS: p_file TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f_selecionar_arquivo.

START-OF-SELECTION.

  PERFORM f_exportar_dados.

*---------------------------------------------------------------------*

*---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA: gv_filename TYPE string,
        gv_header   TYPE string,
        gv_line     TYPE string,
    gt_file     TYPE STANDARD TABLE OF string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = sy-datum && '_SENIOR_1008.csv'.

  gv_header = 'CODBAN;CODAGE;NOMAGE;CODEST;CODCID;DIGAGE'.

*---------------------------------------------------------------------*
* Coletar dados do empregado (origem real das agÃªncias)
*---------------------------------------------------------------------*

  SELECT DISTINCT
    bankl
  INTO TABLE @DATA(gt_bankl)
  FROM pa0009
  WHERE bankl NE ''.

*---------------------------------------------------------------------*
* Ordenar e evitar duplicidade
*---------------------------------------------------------------------*

  SORT gt_bankl BY bankl.
  DELETE ADJACENT DUPLICATES FROM gt_bankl COMPARING bankl.

*---------------------------------------------------------------------*
* Buscar dados do banco
*---------------------------------------------------------------------*

  SELECT
    bankl,
    banka,
    ort01,
    provz
  INTO TABLE @DATA(gt_bnka)
  FROM bnka
  FOR ALL ENTRIES IN @gt_bankl
  WHERE bankl = @gt_bankl-bankl
    AND banks = 'BR'.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  LOOP AT gt_bankl ASSIGNING FIELD-SYMBOL(<fs_bank>).

    DATA: lv_codban TYPE string,
          lv_codage TYPE string,
          lv_nome   TYPE string,
          lv_estado TYPE string,
          lv_cidade TYPE string,
          lv_dig    TYPE string.

*---------------------------------------------------------------------*
* Banco / AgÃªncia
*---------------------------------------------------------------------*

    lv_codban = <fs_bank>-bankl(3).
    lv_codage = <fs_bank>-bankl+3.

*---------------------------------------------------------------------*
* Buscar dados BNKA
*---------------------------------------------------------------------*

    READ TABLE gt_bnka ASSIGNING FIELD-SYMBOL(<fs_bnka>)
      WITH KEY bankl = <fs_bank>-bankl.

    IF sy-subrc = 0.
      lv_nome   = <fs_bnka>-banka. " fallback
      lv_estado = <fs_bnka>-PROVZ.
      lv_cidade = <fs_bnka>-ort01.
    ENDIF.

*---------------------------------------------------------------------*
* Ajustes
*---------------------------------------------------------------------*

    IF lv_nome IS INITIAL.
      lv_nome = 'AGENCIA'.
    ENDIF.

    lv_dig = ''. " nÃ£o existe no SAP

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      lv_codban && ';' && " CODBAN
      lv_codage && ';' && " CODAGE
      lv_nome   && ';' && " NOMAGE
      lv_estado && ';' && " CODEST
      lv_cidade && ';' && " CODCID (precisa conversÃ£o IBGE)
      lv_dig.             " DIGAGE

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo USING gv_filename CHANGING gt_file.

  WRITE: / 'Arquivo 1008 gerado:', gv_filename.

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
