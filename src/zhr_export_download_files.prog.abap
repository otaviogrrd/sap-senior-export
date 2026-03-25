REPORT zhr_export_download_files.

PARAMETERS:
  p_date   TYPE datum DEFAULT sy-datum,
  p_path   TYPE sapb-sappfad DEFAULT '/tmp/',
  p_pathto TYPE sapb-sappfad,
  p_max    TYPE i DEFAULT 99999,
  p_from   TYPE i DEFAULT 1,
  p_upto   TYPE i DEFAULT 0.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_pathto.
  PERFORM f_selecionar_diretorio_arquivo.

START-OF-SELECTION.

  IF p_path IS INITIAL.
    MESSAGE 'Informe o caminho de origem dos arquivos.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF p_pathto IS INITIAL.
    MESSAGE 'Informe o caminho para salvar os arquivos.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF p_max IS INITIAL OR p_max <= 0.
    MESSAGE 'Informe uma quantidade máxima válida de arquivos.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM f_normalizar_caminhos.
  PERFORM f_download_files.

*&---------------------------------------------------------------------*
*& Form F_DOWNLOAD_FILES
*&---------------------------------------------------------------------*
FORM f_download_files.

  DATA: lt_dir_list TYPE STANDARD TABLE OF epsfili,
        ls_dir_list TYPE epsfili,
        lv_dir_name TYPE epsf-epsdirnam,
        lv_source   TYPE sapb-sappfad,
        lv_target   TYPE sapb-sappfad,
        lv_date_c   TYPE char8,
        gv_ok       TYPE i,
        gv_err      TYPE i,
        gv_del_ok   TYPE i,
        gv_del_err  TYPE i.

  lv_date_c = p_date.

  lv_dir_name = p_path.
  CALL FUNCTION 'EPS_GET_DIRECTORY_LISTING'
    EXPORTING
      dir_name               = lv_dir_name
    TABLES
      dir_list               = lt_dir_list
    EXCEPTIONS
      invalid_eps_subdir     = 1
      sapgparam_failed       = 2
      build_directory_failed = 3
      no_authorization       = 4
      read_directory_failed  = 5
      too_many_read_errors   = 6
      empty_directory_list   = 7
      OTHERS                 = 8.

  IF sy-subrc <> 0.
    MESSAGE |Erro ao listar diretório no servidor: { p_path }| TYPE 'E'.
  ENDIF.
  SORT lt_dir_list BY name.

  LOOP AT lt_dir_list ASSIGNING FIELD-SYMBOL(<fs_list>).

    IF <fs_list>-name NP '*.csv'.
      IF <fs_list>-name NS lv_date_c.
        <fs_list>-name = 'ZEXTRA_DELETE'.
      ENDIF.
    ENDIF.

  ENDLOOP.
  DELETE lt_dir_list WHERE name = 'ZEXTRA_DELETE'.

  DESCRIBE TABLE lt_dir_list LINES DATA(vl_lines).
  WRITE: / 'Arquivos encontrados:', vl_lines.

  DATA gv_proc TYPE i.

  SORT lt_dir_list BY size.

  LOOP AT lt_dir_list INTO ls_dir_list FROM p_from.

    IF p_upto > 0.
      IF sy-tabix >= p_upto.
        EXIT.
      ENDIF.
    ENDIF.
    CHECK ls_dir_list-name CP '*.csv'.
    CHECK ls_dir_list-name CS lv_date_c.
    CHECK ls_dir_list-size GT 0.

    IF gv_proc >= p_max.
      EXIT.
    ENDIF.

    CLEAR: lv_source, lv_target.

    CONCATENATE p_path   ls_dir_list-name INTO lv_source.
    CONCATENATE p_pathto ls_dir_list-name INTO lv_target.

    SUBMIT zhr_export_senior_1
           WITH p_path = p_path
           WITH p_pathto = p_pathto
           WITH p_filenam = ls_dir_list-name
           EXPORTING LIST TO MEMORY
           AND RETURN.

    IF sy-subrc = 0.
      ADD 1 TO gv_ok.
      ADD ls_dir_list-size TO gv_proc.

      WRITE: / 'Download realizado:', ls_dir_list-name.

      DELETE DATASET lv_source.
      IF sy-subrc = 0.
        ADD 1 TO gv_del_ok.
      ELSE.
        ADD 1 TO gv_del_err.
      ENDIF.
    ELSE.
      ADD 1 TO gv_err.
      WRITE: / 'Erro no download:', ls_dir_list-name.
    ENDIF.

  ENDLOOP.

  ULINE.
  WRITE: / 'Arquivos baixados:', gv_ok.
  WRITE: / 'Bytes baixados:', gv_proc.
  WRITE: / 'Erros no download:', gv_err.
  WRITE: / 'Arquivos apagados do servidor:', gv_del_ok.
  WRITE: / 'Erros ao apagar do servidor:', gv_del_err.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_NORMALIZAR_CAMINHOS
*&---------------------------------------------------------------------*
FORM f_normalizar_caminhos.

  DATA lv_last TYPE c LENGTH 1.

  DATA(vl_strlen) = strlen( p_path ) - 1.

  IF p_path IS NOT INITIAL.
    lv_last = p_path+vl_strlen(1).
    IF lv_last <> '/'.
      CONCATENATE p_path '/' INTO p_path.
    ENDIF.
  ENDIF.

  vl_strlen = strlen( p_pathto ) - 1.
  IF p_pathto IS NOT INITIAL.
    lv_last = p_pathto+vl_strlen(1).
    IF lv_last <> '\'.
      CONCATENATE p_pathto '\' INTO p_pathto.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_SELECIONAR_DIRETORIO_ARQUIVO
*&---------------------------------------------------------------------*
FORM f_selecionar_diretorio_arquivo.

  DATA: lv_path TYPE string.

  CALL METHOD cl_gui_frontend_services=>directory_browse
    CHANGING
      selected_folder      = lv_path
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc = 0 AND lv_path IS NOT INITIAL.
    p_pathto = lv_path.
  ENDIF.

ENDFORM.
