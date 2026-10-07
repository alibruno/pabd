# Programação e Administração de Banco de Dados

## Sumário

1. [Startar banco já configurado no Codespaces](#startar-banco-já-configurado-no-codespaces)
2. [Comandos úteis do psql](#comandos-úteis-do-psql)
3. [Configurando PostgreSQL no GitHub Codespaces](#configurando-postgresql-no-github-codespaces)

## Startar banco já configurado no codespaces:

- Padrão: `./utils/start_pabd.sh`
- dvdrental: `./utils/start_dvdrental.sh`
- f1db: `./utils/start_f1db.sh`

## Comandos úteis do psql

| Comando | Descrição | Exemplo |
| --- | --- | --- |
| `\l` | Lista os bancos de dados | `\l` |
| `\c` | Conecta a um banco de dados | `\c minha_base` |
| `\dn` | Lista os schemas | `\dn` |
| `\dt` | Lista as tabelas | `\dt` |
| `\dt schema.*` | Lista tabelas de um schema | `\dt public.*` |
| `\d tabela` | Mostra a estrutura de uma tabela | `\d clientes` |
| `\d+ tabela` | Mostra detalhes da tabela | `\d+ clientes` |
| `\dv` | Lista as views | `\dv` |
| `\dm` | Lista materialized views | `\dm` |
| `\di` | Lista os índices | `\di` |
| `\ds` | Lista as sequences | `\ds` |
| `\df` | Lista as funções | `\df` |
| `\df nome` | Consulta funções pelo nome | `\df calcular_total` |


## Configurando PostgreSQL no Github Codespaces:

# 1. Instalando Postgres

```bash
sudo apt update
sudo apt install -y postgresql postgresql-client postgresql-contrib
sudo service postgresql start
```

# 2. Adicionar permissão
```bash
echo "codespace ALL=(postgres) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/codespace-postgres
sudo chmod 440 /etc/sudoers.d/codespace-postgres
```

# 3. Testar
```bash
sudo -u postgres psql -c "SELECT version();"
```

# 4. Criar um novo usuário e novo banco de dados
```bash
sudo -u postgres psql <<'SQL'
CREATE ROLE admin LOGIN PASSWORD 'root' SUPERUSER;
CREATE DATABASE pabd OWNER admin;
SQL
```

`<<'SQL' ... SQL` -> Heredoc: passa várias linhas SQL como entrada para o psql

# 5. Conectar com o novo usuário
```bash
psql -h 127.0.0.1 -U admin -d pabd
```

-h host
-p porta
-U usuário
-d database
-W força o prompt da senha (em vez de confiar em PGPASSWORD ou .pgpass)
-c comando SQL

Diferença importante: aqui usamos `127.0.0.1`, não `localhost`. No PostgreSQL, `localhost` pode tentar conexão via socket Unix (e, em alguns casos, usar autenticação peer), enquanto 127.0.0.1 força a conexão via TCP/IP, onde a autenticação por senha normalmente é exigida. Isso é crucial quando a role foi criada com senha.

# 6. Exibir todas as tabelas
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE';
```

# 7. Comando úteis do psql

Listar todas as tabelas: \dt
Mostrar a descrição de uma tabela: \d TABELA
Executar um arquivo: \i PATH

# 8. Usando `pg_restore` para criar o banco de dados `dvdrental`

Faça o donwload no link (https://neon.com/postgresqltutorial/dvdrental.zip). 

Após descompactar, coloque o arquivo `dvdrental.tar` na pasta `utils`.

```bash
sudo -i -u postgres
psql
```

Uma vez dentro do prompt do PostgreSQL, defina uma senha para o usuário `postgres`:

```sql
ALTER USER postgres PASSWORD 'postgres';
```

Sair do psql e do sudo. Criar o banco de dados `dvdrental`:

```bash
psql -h 127.0.0.1 -U postgres
```

Dentro do psql: 

```sql
CREATE DATABASE dvdrental;
```

Sair do psql. Depois, no terminal:

```bash
pg_restore -h 127.0.0.1 -U postgres -d dvdrental utils/dvdrental.tar 
```

Para testar, entre no `psql` e digite:

```bash
\c dvdrental
```

Para exibir todas as tabelas: `\dt`

# 9. Criando banco de dados `f1db`

Faça o donwload no link (https://github.com/f1db/f1db/releases/download/v2026.16.0/f1db-sql-postgresql.zip). 

Após descompactar, coloque o arquivo na pasta `desafios`.

Entre no psql:

```bash
psql -h 127.0.0.1 -U postgres
```

Execute dentro do psql: 

```sql
CREATE DATABASE f1db;
```

Ainda no psql, faça a instalação do banco:

```bash
\i desafios/f1db-sql-postgresql.sql;
```