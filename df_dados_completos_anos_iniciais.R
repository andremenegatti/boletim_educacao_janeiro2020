library(cagedExplorer)
source('dotplot_regions.R')

# CARREGANDO BASES ------------------------------------------------------------
# Notas IDEB
ideb_iniciais <- readRDS('data/df_ideb_iniciais.rds') %>% 
  mutate(rede = tolower(rede) %>% str_replace(pattern = '\u00fa', replacement = 'u'))

# Percentual de docentes com curso superior
dsu2017 <- readxl::read_excel('data/DSU_2017.xlsx', sheet = 1, range = 'A1:E646', col_names = TRUE) %>% 
  select(Codmun7, doc_sup = DSU_F14)

# Indice de adequacao docente
ird2017 <- readxl::read_excel('data/regularidade_docente_sp_rede_publica.xlsx', sheet = 1,
                              range = 'A1:F646', col_names = TRUE) %>% 
  mutate(nota_ird = ird_baixa * 1 + ird_media_baixa * 2 + ird_media_alta * 3 + ird_alta * 4)

# Despesas com educacao
despesas_educ_2017 <- readxl::read_excel('data/despesas_educacao_municipios.xlsx', sheet = 2,
                                         range = 'A1:F646', col_names = TRUE)
# Populacao 2017
pop_ibge_2017 <- readxl::read_excel('data/estimativa_populacao_municipios_2017.xlsx', sheet = 1,
                              range = 'A1:C5571', col_names = TRUE) %>% 
  filter(str_detect(Codmun7, '35\\d{5}')) %>% 
  select(-municipio) %>%
  rename(pop_ibge = pop2017) %>% 
  mutate(Codmun7 = as.integer(Codmun7))

# Matriculas anos iniciais do EF
matriculas_iniciais <- readRDS('data/matriculas_iniciais_long.rds')

# PIB
pib_2017 <- readxl::read_excel('data/pib_municipios_2017.xlsx', sheet = 1,
                          range = 'A1:C5571', col_names = TRUE) %>% 
  select(-municipio) %>% 
  filter(str_detect(codigo, '35\\d{5}')) %>% 
  mutate(codigo = as.integer(codigo))

#QEdu
qedu <- readxl::read_excel('data/qedu.xlsx', sheet = 1,
                                 range = 'A1:J646', col_names = TRUE) %>% 
  select(municipio, perc_adequado_port = perc_adequado) %>% 
  inner_join(readxl::read_excel('data/qedu.xlsx', sheet = 2,
                                range = 'A1:J646', col_names = TRUE) %>% 
               select(municipio, perc_adequado_mat = perc_adequado,
                      matriculados_5ano = matriculados),
             by = 'municipio') %>% 
  mutate(perc_adequado_avg = (perc_adequado_port + perc_adequado_mat) / 2) %>% 
  mutate(municipio = cagedExplorer::clean_text(municipio)) %>% 
  mutate(municipio = case_when(municipio == 'FLORINIA' ~ 'FLORINEA',
                               municipio == 'EMBU' ~ 'EMBU DAS ARTES',
                               municipio == 'MOJI MIRIM' ~ 'MOGI MIRIM',
                               municipio == 'SAO LUIS DO PARAITINGA' ~ 'SAO LUIZ DO PARAITINGA',
                               TRUE ~ municipio))

# Juntando dados e organizando ------------------------------------------------
df_iniciais <- municipios_sp %>% 
  select(Codmun7, municipio, municipio_clean, regiao_administrativa, regiao_governo) %>% 
  left_join(ideb_iniciais %>% 
              filter(rede == 'publica') %>% 
              select(Codmun7, taxa_aprov_iniciais_2017,
                     ind_rend_iniciais_2017, saeb_iniciais_2017, ideb_iniciais_2017),
            by = 'Codmun7') %>% 
  left_join(matriculas_iniciais %>% 
              filter(rede == 'publica') %>% 
              select(Codmun7, matriculas, municipalizacao),
            by = 'Codmun7') %>% 
  left_join(pop_ibge_2017, by = 'Codmun7') %>% 
  left_join(despesas_educ_2017 %>% select(-municipio),
            by = c('Codmun7' = 'codigo_ibge')) %>% 
  left_join(pib_2017, by = c('Codmun7'= 'codigo')) %>% 
  left_join(dsu2017, by = 'Codmun7') %>% 
  left_join(ird2017 %>% select(-municipio), by = 'Codmun7') %>% 
  left_join(qedu, by = c('municipio_clean' = 'municipio'))

names(df_iniciais) <- names(df_iniciais) %>% str_remove('_iniciais_2017')

# Criando variavel com faixas de tamanho --------------------------------------
df_iniciais <- df_iniciais %>% 
  mutate(faixa_tamanho =
           cut(pop_ibge,
               breaks = c(0, 5e+3, 25e+3, 50e+3, 100e+3, 250e+3, 500e+3, 12106920),
               labels = c('Até 5 mil',
                          '5 mil a 25 mil',
                          '25 mil a 50 mil',
                          '50 mil a 100 mil',
                          '100 mil a 250 mil',
                          '250 mil a 500 mil',
                          'Mais de 500 mil'))
  ) %>% 
  mutate(faixa_tamanho = fct_reorder(faixa_tamanho, pop_ibge, .fun = function(x) - mean(x, na.rm = TRUE)))

glimpse(df_iniciais)

saveRDS(df_iniciais, 'data/df_dados_completos_anos_iniciais.rds')
