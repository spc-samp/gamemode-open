// Inclu�mos a biblioteca padr�o do open.mp, que inclui todas as fun��es nativas
#include <open.mp>

// Inclu�mos bibliotecas externas que usaremos
#include <a_mysql>
#include <samp_bcrypt>
#include <env>
#include <YSI_Data/y_iterate>

// Criamos o identificador da conex�o com o banco de dados (conhecido como handle - https://pt.wikipedia.org/wiki/Handle_(inform%C3%A1tica))
new MySQL:Handle;

// M�dulos - Caminho: compiler/include/modules/nome_do_modulo
#include <modules/server/constants>
#include <modules/server/dialogs>
#include <modules/account/login>

// Definimos aqui elementos essenciais: nome do servidor, t�tulo da gamemode, nome do mapa e linguagem do servidor
#define SERVER_TITLE "Nome do servidor"
#define GAMEMODE_TITLE "Gamemode"
#define MAPNAME "Los Santos"
#define LANGUAGE "Portugu�s"

main() {
    print("Servidor online!");
}

public OnGameModeInit() {
    // Definimos as vari�veis para armazenar as credenciais necess�rias para conectar ao banco de dados
    new host[15], user[15], password[15], database[15], MySQLOpt:options;

    // Habilitamos reconex�o autom�tica caso a conex�o com o banco de dados caia por ventura
    mysql_set_option(options, AUTO_RECONNECT, true);

    // Recuperamos as credenciais armazenadas no nosso arquivo .env 
    // e as armazenamos em nossas vari�veis posteriormente criadas
    Env_Get("MYSQL_HOST", host);
    Env_Get("MYSQL_USER", user);
    Env_Get("MYSQL_PASSWORD", password);
    Env_Get("MYSQL_DATABASE", database);

    // Tentamos conectar ao banco de dados com as credenciais armazenadas em nossas vari�veis
    Handle = mysql_connect(host, user, password, database);

    // Imprimimos um erro no console caso haja alguma falha
    if(mysql_errno(Handle) != 0 || Handle == MYSQL_INVALID_HANDLE) {
        print("Houve um erro inesperado ao tentar estabelecer conex�o com o banco de dados. Verifique se o banco de dados est� ativo e se as credenciais est�o corretas.");
    }

    // Aqui configuramos v�rios comportamentos do servidor
    // e.g. Habilitamos o uso da anima��o de correr/andar do personagem do CJ, que por padr�o utiliza a anima��o de NPC
    // desabilitamos entradas e sa�das de interiores padr�es
    // Definimos o nome e linguagem do servidor, nome do mapa e t�tulo da gamemode
    // e desabilitamos stunt bonuses 
    // i.e. b�nus em dinheiro de manobras que existem no modo hist�ria quando voc� realiza uma manobra excepcional com um ve�culo
    UsePlayerPedAnims();
    DisableInteriorEnterExits();
    EnableStuntBonusForAll(false);
    SendRconCommand("name "#SERVER_TITLE"");
    SendRconCommand("game.map "#MAPNAME"");
    SendRconCommand("language "#LANGUAGE"");
    SetGameModeText(GAMEMODE_TITLE);
    return 1;
}

public OnGameModeExit() {
    // Terminamos a conex�o do banco de dados quando o servidor desliga/reinicia para evitar duplicar a conex�o
    mysql_close(Handle);

    // Imprimimos uma mensagem no console dizendo que o servidor foi reiniciado
    print("Servidor reiniciando... aguarde");
    return 1;
}