REPORT zhr_senior_exp_1001.

PARAMETERS:
  p_serv TYPE sapb-sappfad DEFAULT '/tmp/'.

START-OF-SELECTION.

  IF p_serv IS INITIAL.
    MESSAGE 'Informe o caminho de destino do arquivo no servidor.' TYPE 'E'.
  ENDIF.

  PERFORM f_normalizar_caminhos.
  PERFORM f_exportar_dados.

*---------------------------------------------------------------------*
FORM f_normalizar_caminhos.

  DATA lv_last TYPE c LENGTH 1.

  DATA(vl_strlen) = strlen( p_serv ) - 1.

  IF p_serv IS NOT INITIAL.
    lv_last = p_serv+vl_strlen(1).
    IF lv_last <> '/'.
      CONCATENATE p_serv '/' INTO p_serv.
    ENDIF.
  ENDIF.

ENDFORM.

*---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA:
    gv_filename TYPE string,
    gv_header   TYPE string,
    gv_line     TYPE string.

  DATA:
    address       LIKE sadr,
    branch_record LIKE j_1bbranch,
    cgc_number    LIKE j_1bwfield-cgc_number.

  DATA:
    ls_adr2 TYPE adr2.

  gv_filename = p_serv && sy-datum && '_SENIOR_1001.csv'.
  gv_header =
'NUMEMP;CODFIL;RAZSOC;NOMFIL;ENDFIL;CPLFIL;ENDNUM;CODBAI;CODEST;CODCID;DDITEL;DDDTEL;NUMTEL'.



  SELECT *
    INTO TABLE @DATA(tl_t001)
    FROM t001
   WHERE bukrs LIKE 'BR%'.

  IF sy-subrc NE 0.
    MESSAGE 'Nenhum dado encontrado na tabela T001.' TYPE 'E'.
  ENDIF.


  SELECT *
    INTO TABLE @DATA(tl_branch)
    FROM j_1bbranch
    FOR ALL ENTRIES IN @tl_t001
   WHERE bukrs = @tl_t001-bukrs.

  OPEN DATASET gv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao abrir arquivo.' TYPE 'E'.
  ENDIF.

  TRANSFER gv_header TO gv_filename.


  LOOP AT tl_branch ASSIGNING FIELD-SYMBOL(<fs_branch>).


    CALL FUNCTION 'J_1B_BRANCH_READ'
      EXPORTING
        branch            = <fs_branch>-branch
        company           = <fs_branch>-bukrs
      IMPORTING
        address           = address
        branch_record     = branch_record
        cgc_number        = cgc_number
      EXCEPTIONS
        branch_not_found  = 1
        address_not_found = 2
        company_not_found = 3
        OTHERS            = 4.


    CLEAR ls_adr2.

    SELECT SINGLE *
      INTO ls_adr2
      FROM adr2
     WHERE addrnumber = address-adrnr.


    DATA(lv_ddi) = ''.
    DATA(lv_ddd) = ''.
    DATA(lv_tel) = ||.

    IF ls_adr2-tel_number IS NOT INITIAL.

      lv_tel = ls_adr2-tel_number.

      IF strlen( lv_tel ) > 4.
        lv_ddd = lv_tel+0(3).
        lv_tel = lv_tel+3.
      ENDIF.

    ENDIF.

    gv_line =
          <fs_branch>-bukrs            && ';'
        && <fs_branch>-branch          && ';'
        && branch_record-name          && ';'
        && branch_record-name          && ';'
        && address-stras               && ';'
        && address-strs2               && ';'
        && address-hausn               && ';'
        && ''                          && ';'
        && address-regio               && ';'
        && ''                          && ';'
        && lv_ddi                      && ';'
        && lv_ddd                      && ';'
        && lv_tel.

    TRANSFER gv_line TO gv_filename.

  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo gerado:', gv_filename.

ENDFORM.
