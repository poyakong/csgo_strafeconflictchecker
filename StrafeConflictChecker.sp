#include <sourcemod>
#include <sdktools>

// 测试用
#define DEBUG 0

char strafeHistory[128];
char leftHistory[128];
char rightHistory[128];
int historyIndex = 0;
bool isRecording = false;

// HUD控制变量
Handle g_hSyncHud = INVALID_HANDLE;

// cfg配置文件
char g_sConfigFile[PLATFORM_MAX_PATH];

static float lastAngles[MAXPLAYERS + 1][3];
// static bool strafeHudEnable[MAXPLAYERS + 1] = { true };
// static float strafeHud_x[MAXPLAYERS + 1] = -1.0;
// static float strafeHud_y[MAXPLAYERS + 1] = 0.1;
static bool strafeHudEnable_solo = true;
static float strafeHud_x_solo = -1.0;
static float strafeHud_y_solo = 0.2;

public Plugin myinfo = 
{
	name = "Strafe Conflict Checker",
	author = "poyakong",
	description = "Strafe Conflict Checker",
	version = "0.1.2",
	url = "https://github.com/poyakong"
};

public void OnPluginStart() 
{
	// 创建同步HUD文本
	g_hSyncHud = CreateHudSynchronizer();

	// 注册控制HUD的控制台指令
	RegConsoleCmd("sm_strafehud", Command_StrafeHud, "Toggle Strafe HUD display");

	// 加载配置
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/strafeconflictchecker.cfg");
	LoadConfig();
}

public void OnPluginEnd()
{
	if (g_hSyncHud != INVALID_HANDLE)
	{
		CloseHandle(g_hSyncHud);
	}

	// 保存配置
	SaveConfig();
}

public Action Command_StrafeHud(int client, int args)
{
	if (args < 1)
	{
		strafeHudEnable_solo = !strafeHudEnable_solo;
		ReplyToCommand(client, "[SM] Strafe HUD %s", strafeHudEnable_solo ? "Enabled" : "Disabled");
	} else if (args == 2){
		char buffer1[16], buffer2[16];
		strafeHudEnable_solo = true;
		GetCmdArg(1, buffer1, sizeof(buffer1));
		GetCmdArg(2, buffer2, sizeof(buffer2));
		strafeHud_x_solo = StringToFloat(buffer1);
		strafeHud_y_solo = StringToFloat(buffer2);
		ReplyToCommand(client, "[SM] Strafe HUD position set to %.1f, %.1f", strafeHud_x_solo, strafeHud_y_solo);
	} else {
		ReplyToCommand(client, "[SM] Usage: sm_strafehud [x] [y]\nrange from 0 to 1\n0.5 is the center of the screen");
	}

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!IsPlayerAlive(client) || !strafeHudEnable_solo) return Plugin_Continue;

	// 计算strafe方向（基于yaw变化）
	float yawDelta = NormalizeAngle(angles[1] - lastAngles[client][1]);
	
	// 根据yaw变化确定strafe方向
	char strafeSymbol = '-';
	int strafeAngleDirection = 0;
	if (yawDelta > 0){
		strafeSymbol = '<';
		strafeAngleDirection = 1;
		}  // 视角向左
	else if (yawDelta < 0){
		strafeSymbol = '>';
		strafeAngleDirection = 2;
	}  // 视角向右

	// 更新上一tick的角度
	lastAngles[client][1] = angles[1];

	// 检查是否在空中并记录按键历史
	if (GetEntityFlags(client) & FL_ONGROUND == 0) 
	{
		// 记录历史
		if (!isRecording) 
		{
			ResetHistory();
			isRecording = true;
		}

		strafeHistory[historyIndex] = strafeSymbol;
		leftHistory[historyIndex] = (buttons & IN_MOVELEFT) ? 'A' : '-';
		rightHistory[historyIndex] = (buttons & IN_MOVERIGHT) ? 'D' : '-';

		historyIndex++;

		// 检查历史记录是否已满
		if (historyIndex >= 124) 
		{
			PrintHistoryToConsole(client);
			ResetHistory();
		}
	}
	else if (isRecording && GetEntityFlags(client) & FL_ONGROUND) 
	{
		// 玩家落地，打印历史
		PrintHistoryToConsole(client);
		ResetHistory();
	}

	// 显示HUD信息
	char hudMessage[64];
	int buttonsPressed = buttons;
	Format(hudMessage, sizeof(hudMessage), 
		"%s—%s\n%s—%s", 
		(strafeAngleDirection == 1) ? "<" : "—", (strafeAngleDirection == 2) ? ">" : "—",
		(buttonsPressed & IN_MOVELEFT) ? "A" : "—", (buttonsPressed & IN_MOVERIGHT) ? "D" : "—"
	);
	if(strafeAngleDirection == 1 && (buttonsPressed & IN_MOVERIGHT))
	{
		SetHudTextParams(strafeHud_x_solo, strafeHud_y_solo, 0.1, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
	} else if(strafeAngleDirection == 2 && (buttonsPressed & IN_MOVELEFT))
	{
		SetHudTextParams(strafeHud_x_solo, strafeHud_y_solo, 0.1, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
	} else {
	SetHudTextParams(strafeHud_x_solo, strafeHud_y_solo, 0.1, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	}
	ShowSyncHudText(client, g_hSyncHud, hudMessage);

	return Plugin_Continue;
}

// 标准化角度，确保在-180到180度范围内
float NormalizeAngle(float angle)
{
	while (angle > 180.0) angle -= 360.0;
	while (angle < -180.0) angle += 360.0;
	return angle;
}

void PrintHistoryToConsole(int client) 
{
	if (historyIndex > 0) 
	{
		PrintToConsole(client, "Strafe History:");
		PrintToConsole(client, "%s", strafeHistory);
		PrintToConsole(client, "%s", leftHistory);
		PrintToConsole(client, "%s\n", rightHistory);
	}
}

void ResetHistory() 
{
	// 重置所有历史数组和索引
	for (int i = 0; i < 128; i++) 
	{
		strafeHistory[i] = '\0';
		leftHistory[i] = '\0';
		rightHistory[i] = '\0';
	}
	historyIndex = 0;
	isRecording = false;
}

// 20250307 CFG保存功能
// 添加新函数：加载配置
void LoadConfig()
{
	// 检查文件是否存在
	if (FileExists(g_sConfigFile))
	{
		// 创建KeyValues句柄
		Handle kvConfig = CreateKeyValues("StrafeConflictChecker");
		
		// 尝试从文件中加载键值
		if (FileToKeyValues(kvConfig, g_sConfigFile))
		{
			// 读取配置值
			strafeHudEnable_solo = view_as<bool>(KvGetNum(kvConfig, "strafeHudEnable_solo", 1));
			strafeHud_x_solo = KvGetFloat(kvConfig, "strafeHud_x_solo", -1.0);
			strafeHud_y_solo = KvGetFloat(kvConfig, "strafeHud_y_solo", 0.1);
			
			PrintToServer("[Strafe Conflict] Config loaded: enabled=%d, x=%.1f, y=%.1f", 
				strafeHudEnable_solo, strafeHud_x_solo, strafeHud_y_solo);
		}
		else
		{
			PrintToServer("[Strafe Conflict] Failed to load config, using defaults");
		}
		
		// 关闭句柄
		CloseHandle(kvConfig);
	}
	else
	{
		PrintToServer("[Strafe Conflict] Config file not found, using defaults");
		// 创建默认配置
		SaveConfig();
	}
}

// 添加新函数：保存配置
void SaveConfig()
{
	// 创建KeyValues句柄
	Handle kvConfig = CreateKeyValues("StrafeConflictChecker");
	
	// 设置值
	KvSetNum(kvConfig, "strafeHudEnable_solo", view_as<int>(strafeHudEnable_solo));
	KvSetFloat(kvConfig, "strafeHud_x_solo", strafeHud_x_solo);
	KvSetFloat(kvConfig, "strafeHud_y_solo", strafeHud_y_solo);
	
	// 保存到文件
	KvRewind(kvConfig);
	if(KeyValuesToFile(kvConfig, g_sConfigFile))
	{
		PrintToServer("[Strafe Conflict] Config saved: enabled=%d, x=%.1f, y=%.1f", 
		strafeHudEnable_solo, strafeHud_x_solo, strafeHud_y_solo);
	} else {
		PrintToServer("[Strafe Conflict] Failed to save config");
	}
	
	
	// 关闭句柄
	CloseHandle(kvConfig);
	
	
}

