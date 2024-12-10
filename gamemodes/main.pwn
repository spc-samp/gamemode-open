// Inclu�mos a biblioteca padr�o do open.mp, que inclui todas as fun��es nativas
#include <open.mp>

// Inclu�mos bibliotecas externas que usaremos
#include <a_mysql>
#include <samp_bcrypt>
#include <env>

// Criamos o identificador da conex�o com o banco de dados (conhecido como handle - https://pt.wikipedia.org/wiki/Handle_(inform%C3%A1tica))
new MySQL:Handle;

// Definimos aqui elementos essenciais: nome do servidor, t�tulo da gamemode, nome do mapa e linguagem do servidor
#define SERVER_TITLE "Nome do servidor"
#define GAMEMODE_TITLE "Gamemode"
#define MAPNAME "Los Santos"
#define LANGUAGE "Portugu�s"

// Criamos um enumerador com v�rias vari�veis que usaremos para armazenar informa��es do jogador na mem�ria
enum E_PLAYER_DATA {
    pID,
    pName[MAX_PLAYER_NAME],
    pHash[BCRYPT_HASH_LENGTH],
    pLoginAttempts,
    bool:pLoggedin,

    pSkin,
    pSex,
    Float:pPosX,
    Float:pPosY,
    Float:pPosZ,
    Float:pAngle
};
// Criamos uma matriz para acessar as vari�veis dentro do enumerador
new PlayerData[MAX_PLAYERS][E_PLAYER_DATA];

// Definimos valores padr�es como coordenadas do spawn padr�o/novato e skin inicial de cada g�nero
#define DEFAULT_POS_X 1480.9602
#define DEFAULT_POS_Y -1745.0508
#define DEFAULT_POS_Z 13.5469
#define DEFAULT_ANGLE 3.2307
#define MASCULINE_DEFAULT_SKIN (18)
#define FEMININE_DEFAULT_SKIN (56)

// Defini��es de dialog
#define DIALOG_REGISTRO (0)
#define DIALOG_LOGIN (1)
#define DIALOG_SEX (2)

// Constantes - vari�veis read-only
const GENDER_MASCULINE = 0;
const GENDER_FEMININE = 1;
const MAX_LOGIN_ATTEMPTS = 5;

// Defini��o de macro isnull para verificar se uma string � nula (vazia)
#if !defined isnull
    #define isnull(%1) ((!(%1[0])) || (((%1[0]) == '\1') && (!(%1[1]))))
#endif

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
    } else {
        // Caso n�o haja nenhum problema ao estabelecer conex�o
        // Imprimimos uma mensagem noticiando o status da conex�o (sucesso)
        print("Conex�o com o banco de dados estabelecida com sucesso");
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

public OnPlayerConnect(playerid) {
    // Criamos um buffer para armazenar a query SQL que iremos executar
    new queryBuffer[128];

    // Pegamos o nome/apelido do jogador e armazenamos na vari�vel pName
    GetPlayerName(playerid, PlayerData[playerid][pName]);

    // Aqui colocamos o jogador como espectador 
    // - neste contexto serve apenas como uma "gambiarra" comum para esconder as op��es de spawn padr�es do SA-MP (>> << Spawn)
    // uma vez que n�o h� outra maneira de desabilitar
    TogglePlayerSpectating(playerid, true);

    // Configuramos um movimento de c�mera apenas para n�o ficar parado na tela padr�o do SA-MP
    // Caso queira criar um preset pr�prio
    // D� uma olhada neste editor in-game: https://pastebin.com/NgPvC6Ft
    InterpolateCameraPos(playerid, 1733.424072, -1298.029052, 61.145336, 402.501586, -1333.996337, 59.316917, 70000);
    InterpolateCameraLookAt(playerid, 1728.425170, -1298.034790, 61.247211, 397.503631, -1334.138793, 59.309425, 5000);

    // Armazenamos a query SQL no nosso buffer
    // Dica: sempre utilize mysql_format quando for formatar uma query SQL
    // uma vez que permite escaparmos strings e protege contra vulnerabilidades de SQL Injection (https://pt.wikipedia.org/wiki/Inje%C3%A7%C3%A3o_de_SQL)
    mysql_format(Handle, queryBuffer, sizeof(queryBuffer), "SELECT Hash FROM jogadores WHERE Nome = '%e'", PlayerData[playerid][pName]);
    
    // Executamos a query e chamamos a callback CheckAccount por onde poderemos manipular os resultados da query
    // Dica: sempre utilize a fun��o mysql_tquery em vez da mysql_query
    // o "t" em tquery � abrevia��o de threaded query
    // o que significa que a query vai ser executada em apenas uma thread 
    // enquanto a fun��o mysql_query executar� a query em qualquer thread que estiver dispon�vel no momento
    // e isso pode causar problemas de "hanging", ou seja, travamento do servidor
    // uma vez que estar� utilizando v�rias threads ao mesmo tempo, e, portanto, drenando recursos
    mysql_tquery(Handle, queryBuffer, "CheckAccount", "i", playerid);
}

public OnPlayerDisconnect(playerid, reason) {
    // Tomemos nota nessa express�o, pois certamente tem potencial de causar confus�o
    // Aqui n�s verificamos se o motivo da sa�da do jogador � 1 (ou seja, se o jogador crashou)
    // e especificamente fazemos isso aqui porque quando o jogador crasha
    // n�o � poss�vel recuperar sua posi��o posteriormente
    // o que significa que caso ele crashe, a fun��o SaveData n�o vai conseguir recuperar a posi��o do jogador
    // e isso resultar� no jogador sendo spawnado na posi��o salva antes
    if(reason == 1 && PlayerData[playerid][pLoggedin] == true) {
        GetPlayerPos(playerid, PlayerData[playerid][pPosX], PlayerData[playerid][pPosY], PlayerData[playerid][pPosZ]);
        GetPlayerFacingAngle(playerid, PlayerData[playerid][pAngle]);
    }

    // Atualizamos os dados do jogador ao desconectar
    SaveData(playerid);
    
    // Resetamos as vari�veis do jogador
    // - o que � essencial
    // pois caso n�o fizermos isso, o jogador que conectar e receber o ID do jogador que desconectou
    // ir� "herdar" o valor das vari�veis associadas �quele ID
    ResetData(playerid);
    return 1;
}

public OnPlayerRequestClass(playerid, classid) {
    if(PlayerData[playerid][pLoggedin]) {
        SpawnPlayer(playerid);
    }
}

forward CheckAccount(playerid);
public CheckAccount(playerid) {
    // Verificamos se a coluna do jogador � maior que 0 - ou seja, se existe
    // Se sim, significa que a conta j� est� registrada
    if(cache_num_rows() > 0) {
        // Recuperamos o hash gerado apartir da senha do jogador
        cache_get_value_name(0, "Hash", PlayerData[playerid][pHash], BCRYPT_HASH_LENGTH);

        // Mostramos a dialog de login
        ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login - Digite sua senha", "{FFFFFF}Conta encontrada no banco de dados\n\nDigite sua senha", "Login", "Sair");
    } else {
        // else, ou seja, caso contr�rio (i.e caso a conta n�o esteja registrada), mostramos a dialog de registro
        ShowPlayerDialog(playerid, DIALOG_REGISTRO, DIALOG_STYLE_PASSWORD, "Registro - Digite uma senha para registrar-se", "{FFFFFF}Digite uma senha para registrar-se", "Registrar", "Sair");
    }
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {
    switch(dialogid) {
        case DIALOG_REGISTRO: {
            // Caso ele clique em sair, o expulsamos
            if(!response) return Kick(playerid);

            // Verficamos se a senha cont�m ao menos 5 caracteres
            // caso n�o, mostramos uma mensagem de erro e exibimos a dialog novamente
            if(strlen(inputtext) <= 5) {
                SendClientMessage(playerid, -1, "A senha deve conter pelo menos 5 caracteres");
                return ShowPlayerDialog(playerid, DIALOG_REGISTRO, DIALOG_STYLE_PASSWORD, "Registro - Digite uma senha para registrar-se", "{FFFFFF}Digite uma senha para registrar-se", "Registrar", "Sair");
            }

            // Geramos um hash apartir da senha do jogador
            // Isso � essencial pois armazenar senhas sem nenhuma seguran�a em texto
            // � um erro de seguran�a grav�ssimo
            // e � contra a maioria das leis de privacidade, como a LGPD no Brasil e GDPR na Uni�o Europeia
            bcrypt_hash(playerid, "OnPlayerPasswordHash", inputtext, BCRYPT_COST);
        }

        case DIALOG_LOGIN: {
            if(!response) return Kick(playerid);

            if(isnull(inputtext)) {
                ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login - Digite sua senha", "{FFFFFF}Conta encontrada no banco de dados\n\nDigite sua senha", "Login", "Sair");
                return SendClientMessage(playerid, -1, "Digite uma senha");
            }

            // Verificamos se a senha digitada pelo jogador corresponde ao hash
            // E transmitimos para a callback OnPlayerPasswordVerify onde poderemos manipular os resultados
            bcrypt_verify(playerid, "OnPlayerPasswordVerify", inputtext, PlayerData[playerid][pHash]);
        }


        case DIALOG_SEX: {
            if(response) { // Bot�o esquerdo, ou seja, masculino
                PlayerData[playerid][pSex] = GENDER_MASCULINE;

                TogglePlayerSpectating(playerid, false);
                SetSpawnInfo(playerid, NO_TEAM, MASCULINE_DEFAULT_SKIN, DEFAULT_POS_X, DEFAULT_POS_Y, DEFAULT_POS_Z, DEFAULT_ANGLE);
                SpawnPlayer(playerid);
            } else { // Bot�o direito, ou seja, feminino
                PlayerData[playerid][pSex] = GENDER_FEMININE;

                TogglePlayerSpectating(playerid, false);
                SetSpawnInfo(playerid, NO_TEAM, FEMININE_DEFAULT_SKIN, DEFAULT_POS_X, DEFAULT_POS_Y, DEFAULT_POS_Z, DEFAULT_ANGLE);
                SpawnPlayer(playerid);
            }
        }
    }
    return 1;
}

forward OnPlayerPasswordHash(playerid);
public OnPlayerPasswordHash(playerid) {
    // Criamos uma string para armazenar o hash
    new hash[BCRYPT_HASH_LENGTH];

    // Recuperamos o hash e armazenamos em nossa string
    bcrypt_get_hash(hash, sizeof(hash));

    // Inserimos a conta do jogador no banco de dados
    InsertIntoDatabase(playerid, hash);
    return 1;
}

forward OnPlayerPasswordVerify(playerid, bool:success);
public OnPlayerPasswordVerify(playerid, bool:success) {
    // Caso a senha do jogador n�o corresponda ao hash
    if(!success) {
        // Adiciona uma tentativa de login incorreta
        PlayerData[playerid][pLoginAttempts]++;

        // Aqui criamos uma vari�vel para armazenar quantas tentativas o jogador tem sobrando
        new attempts = MAX_LOGIN_ATTEMPTS - PlayerData[playerid][pLoginAttempts];

        // Caso ele tiver menos que 3 tentativas de 5, mostramos um aviso dizendo que ele possui poucas tentativas sobrando
        if(attempts <= 3) {
            new string[128];
            format(string, sizeof(string), "{FF0000}Senha incorreta!\n\n{FFFFFF}Voc� agora possui apenas {FF0000}%i{FFFFFF} tentativas restantes", attempts);

            ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login - Digite sua senha", string, "Login", "Sair");
        } else {
            ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login - Digite sua senha", "{FF0000}Senha incorreta\n\nTente novamente", "Login", "Sair");
        }

        if(PlayerData[playerid][pLoginAttempts] >= MAX_LOGIN_ATTEMPTS) {
            return Kick(playerid);
        }
    } else {
        new queryBuffer[128];

        mysql_format(Handle, queryBuffer, sizeof(queryBuffer), "SELECT * FROM jogadores WHERE Nome = '%e' LIMIT 1", PlayerData[playerid][pName]);
        mysql_tquery(Handle, queryBuffer, "OnPlayerLogin", "i", playerid);
    }
    return 1;
}

forward OnPlayerLogin(playerid);
public OnPlayerLogin(playerid) {
    PlayerData[playerid][pLoggedin] = true;
    PlayerData[playerid][pLoginAttempts] = 0;

    // Recuperamos os valores das colunas do cach� do banco de dados e armazenamos em suas respectivas vari�veis
    cache_get_value_name_int(0, "ID", PlayerData[playerid][pID]);
    cache_get_value_name_int(0, "Skin", PlayerData[playerid][pSkin]);
    cache_get_value_name_int(0, "Genero", PlayerData[playerid][pSex]);
    cache_get_value_name_float(0, "X_pos", PlayerData[playerid][pPosX]);
    cache_get_value_name_float(0, "Y_pos", PlayerData[playerid][pPosY]);
    cache_get_value_name_float(0, "Z_pos", PlayerData[playerid][pPosZ]);
    cache_get_value_name_float(0, "Angle", PlayerData[playerid][pAngle]);

    TogglePlayerSpectating(playerid, false);
    SetSpawnInfo(playerid, NO_TEAM, PlayerData[playerid][pSkin], PlayerData[playerid][pPosX], PlayerData[playerid][pPosY], PlayerData[playerid][pPosZ], PlayerData[playerid][pAngle]);
    SpawnPlayer(playerid);
    return 1;
}

void:InsertIntoDatabase(playerid, const string:hash[]) {
    new queryBuffer[256];

    // Inserimos a rec�m criada conta do jogador no banco de dados
    mysql_format(Handle, queryBuffer, sizeof(queryBuffer), "INSERT INTO jogadores (Nome, Hash) VALUES ('%e', '%s')", PlayerData[playerid][pName], hash);
    mysql_tquery(Handle, queryBuffer, "OnPlayerRegister", "i", playerid);
}

forward OnPlayerRegister(playerid);
public OnPlayerRegister(playerid) {
    // Mostramos a dialog onde o jogador pode escolher seu g�nero
    ShowPlayerDialog(playerid, DIALOG_SEX, DIALOG_STYLE_MSGBOX, "Sexo - Selecione o g�nero de seu personagem", "{FFFFFF}Selecione seu g�nero", "Masculino", "Feminino");

    PlayerData[playerid][pID] = cache_insert_id();
    
    PlayerData[playerid][pPosX] = DEFAULT_POS_X;
    PlayerData[playerid][pPosY] = DEFAULT_POS_Y;
    PlayerData[playerid][pPosZ] = DEFAULT_POS_Z;
    PlayerData[playerid][pAngle] = DEFAULT_ANGLE;
    
    PlayerData[playerid][pLoggedin] = true;
    PlayerData[playerid][pLoginAttempts] = 0;
    return 1;
}

stock ResetData(playerid) {
    if(!PlayerData[playerid][pLoggedin]) return 1;

    // Aqui resetamos todas as vari�veis para seu valor padr�o
    // Para evitar que outros jogadores as herdem
    PlayerData[playerid][pID] = -1;
    PlayerData[playerid][pName] = EOS; // EOS = End Of String/fim da string - ou seja, reverte o valor da string para seu valor padr�o
    PlayerData[playerid][pHash] = EOS;
    PlayerData[playerid][pLoginAttempts] = 0;
    PlayerData[playerid][pLoggedin] = false;
    PlayerData[playerid][pSkin] = 0;
    PlayerData[playerid][pSex] = -1;
    PlayerData[playerid][pPosX] = 0.0;
    PlayerData[playerid][pPosY] = 0.0;
    PlayerData[playerid][pPosZ] = 0.0;
    PlayerData[playerid][pAngle] = 0.0;
    return 1;
}

stock SaveData(playerid) {
    if(!PlayerData[playerid][pLoggedin]) return 1;

    new queryBuffer[300];


    PlayerData[playerid][pSkin] = GetPlayerSkin(playerid);
    GetPlayerPos(playerid, PlayerData[playerid][pPosX], PlayerData[playerid][pPosY], PlayerData[playerid][pPosZ]);
    GetPlayerFacingAngle(playerid, PlayerData[playerid][pAngle]);

    mysql_format(Handle, queryBuffer, sizeof(queryBuffer), "UPDATE jogadores SET \
    X_Pos = %f, \
    Y_Pos = %f, \
    Z_Pos = %f, \
    Angle = %f, \
    Genero = %i, \
    Skin = %i WHERE ID = %i", PlayerData[playerid][pPosX], PlayerData[playerid][pPosY], PlayerData[playerid][pPosZ], PlayerData[playerid][pAngle], PlayerData[playerid][pSex], PlayerData[playerid][pSkin], PlayerData[playerid][pID]);
    mysql_tquery(Handle, queryBuffer);
    return 1;
}