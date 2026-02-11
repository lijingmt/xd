/**
 * ========================================================================
 * Bot Daemon (BOTD) - 假用户管理器
 * ========================================================================
 *
 * 创建和管理假用户（bot），让游戏看起来更热闹：
 * - 创建200-300个随机假用户
 * - 随机加载到各个房间
 * - Bot 会自动随机移动
 * - Bot 有装备，可以聊天
 *
 * ========================================================================
 */

#include <globals.h>
#include <gamenv/include/gamenv.h>
#include <wapmud2/include/wapmud2.h>

#define BOT_COUNT_MIN 200   // 假用户最小数量
#define BOT_COUNT_MAX 300   // 假用户最大数量
#define CONND ((object)(ROOT + "/pikenv/connd.pike"))

inherit DAEMON;

// Bot 对象列表: bot_id -> bot_object
mapping(string:object) bots = ([]);

// ========================================================================
// 简单的虚拟连接类 - 用于 Bot 注册
// ========================================================================
class BufferConnection {
    string buffer = "";

    void receive(string str) {
        buffer += str;
    }

    string get_output() {
        return buffer;
    }

    void clear() {
        buffer = "";
    }

    int write(string str) {
        buffer += str;
        return str ? sizeof(str) : 1;
    }

    string filter(string str) {
        return str;
    }

    object query_filter() {
        return this_object();
    }

    void set_filter(object f) {
        // 不支持
    }
}

// Bot 名字库 - 网名风格
array(string) male_names = ({
    // 战斗风格
    "狂暴战士", "无敌剑客", "暗影刺客", "烈火法师", "雷霆战神",
    "血色修罗", "绝世高手", "独孤求败", "一剑封喉", "刀锋战士",
    "破军", "贪狼", "七杀", "紫煞", "血刃",
    "战魂", "狂战", "霸主", "至尊", "帝王",
    // 诗意风格
    "清风明月", "云淡风轻", "剑啸九天", "醉卧沙场", "踏雪无痕",
    "逐梦少年", "浪迹天涯", "笑看风云", "逍遥游", "傲世群雄",
    // 酷炫风格
    "极品飞车", "极速传说", "王者归来", "巅峰战神", "绝地反击",
    "龙魂", "凤舞", "天骄", "霸天", "灭世",
    "夜行", "孤影", "幻影", "魅影", "绝影",
    // 英文混合
    "SuperMan", "DarkKnight", "DragonSlayer", "ShadowHunter", "FireStorm",
    "IceKing", "ThunderGod", "NightWalker", "StormRider", "IronFist",
    // 数字字母
    "无敌666", "战神888", "王者520", "巅峰999", "至尊1314",
    "剑客007", "刺客9527", "法师666", "射手888", "坦克999",
    // 可爱风格
    "快乐小鱼", "悠闲乌龟", "蹦蹦兔", "呆呆熊", "憨憨猪",
    "皮皮虾", "小强", "大魔王", "小可爱", "萌萌哒",
});

array(string) female_names = ({
    // 唯美风格
    "月下美人", "樱花飘落", "紫蝶飞舞", "梦幻仙境", "星空漫步",
    "雨后彩虹", "雪中倩影", "清风徐来", "云卷云舒", "花开花落",
    // 诗意风格
    "琴心剑魄", "梦回大唐", "古风美人", "仙气飘飘", "绝代风华",
    "落花有意", "流水无情", "清风明月", "烟雨蒙蒙", "江南烟雨",
    // 可爱风格
    "小仙女", "萌萌兔", "甜甜猫", "爱笑的女孩", "快乐天使",
    "小公主", "甜心宝贝", "萌妹子", "小可爱", "乖乖女",
    "糖糖", "宝宝", "乖乖", "暖暖", "甜甜",
    // 酷炫风格
    "烈焰玫瑰", "冰山雪莲", "暗夜精灵", "幻影魅惑", "绯红女巫",
    "女王范", "御姐风", "女神范", "霸气的妞", "辣妹子",
    // 英文混合
    "SweetGirl", "AngelHeart", "StarDust", "MoonLight", "SunShine",
    "RoseQueen", "IcePrincess", "FirePhoenix", "SnowWhite", "DarkAngel",
    // 特殊符号风格
    "喵星人", "汪星人", "小确幸", "小确丧", "小太阳",
    "小月亮", "小星星", "小彩虹", "小云朵", "小雪花",
});

// 可加载的房间列表（bot 出生点）- 只使用确认可用的房间
array(string) spawn_rooms = ({
    // 北京 (确认可用)
    "gamenv/d/beijing/zhengyangmen",
    "gamenv/d/beijing/chongwenmen",
    "gamenv/d/beijing/gulou",
    "gamenv/d/beijing/nandajie",
    "gamenv/d/beijing/dongdajie",
    // 大理 (确认可用)
    "gamenv/d/dali/daliguangchang",
    "gamenv/d/dali/dalibeimen",
    "gamenv/d/dali/dalinanmen",
    "gamenv/d/dali/dongdajie",
    // 华山 (确认可用)
    "gamenv/d/huashan/huashanjiaoxia",
    "gamenv/d/huashan/huayuan",
    "gamenv/d/huashan/canglongling",
    // 少林 (确认可用)
    "gamenv/d/shaolin/damodong",
    "gamenv/d/shaolin/damoyuan",
    "gamenv/d/shaolin/daxiongbaodian",
    // 武当 (确认可用)
    "gamenv/d/wudang/sanqingdian",
    "gamenv/d/wudang/liangongfang",
    "gamenv/d/wudang/cangjingge",
    // 雪山 (确认可用)
    "gamenv/d/xueshan/binglinfeng",
    "gamenv/d/xueshan/fengjiantai",
    "gamenv/d/xueshan/jiedao1",
    // 黄河 (确认可用)
    "gamenv/d/huanghe/bingcao",
    "gamenv/d/huanghe/guangchang",
    "gamenv/d/huanghe/huanghe",
    // 苏州 (确认可用)
    "gamenv/d/suzhou/dongting",
    // 蜂宫 (确认可用)
    "gamenv/d/fenggong/gongmeng",
    "gamenv/d/fenggong/huayuan",
});

protected void create()
{
    // 延迟初始化，等待游戏环境准备好
    call_out(init_bots, 10);
}

/**
 * 初始化所有 Bot
 */
void init_bots()
{
    // 随机决定 bot 数量 (200-300)
    int bot_count = BOT_COUNT_MIN + random(BOT_COUNT_MAX - BOT_COUNT_MIN + 1);
    werror("[BOTD] ===================== 开始初始化 =====================\n");
    werror("[BOTD] BOT_COUNT_MIN=%d, BOT_COUNT_MAX=%d\n", BOT_COUNT_MIN, BOT_COUNT_MAX);
    werror("[BOTD] 将创建 %d 个 Bot\n", bot_count);

    int created = 0;
    for(int i = 0; i < bot_count; i++) {
        object bot = create_bot(i);
        if(bot) created++;
    }

    werror("[BOTD] Bot 初始化完成，共创建 %d 个 Bot。\n", sizeof(bots));
    werror("[BOTD] 实际成功创建: %d\n", created);
    werror("[BOTD] =====================================================\n");

    // 定期检查并重新创建死亡的 bot
    call_out(check_bots, 300);
}

/**
 * 创建单个 Bot
 */
object create_bot(int index)
{
    string bot_id = "bot_" + index;

    // 如果已存在且有效，跳过
    if(bots[bot_id] && objectp(bots[bot_id]) && environment(bots[bot_id])) {
        return bots[bot_id];
    }

    mixed err = catch {
        // 随机选择性别和名字（不加随机数字）
        string gender = (random(2) == 0) ? "male" : "female";
        string name_cn;
        if(gender == "male")
            name_cn = male_names[random(sizeof(male_names))];
        else
            name_cn = female_names[random(sizeof(female_names))];

        // 随机等级 (10-150)
        int level = 10 + random(140);

        // 创建 bot 对象
        object bot = new(ROOT + "/gamenv/clone/npc/bot_user");
        if(!bot) {
            werror("[BOTD] 创建 Bot 对象失败: %s\n", bot_id);
            return 0;
        }

        // 设置 bot 属性
        bot->set_bot_id(bot_id);
        bot->set_bot_name_cn(name_cn);
        bot->set_bot_gender(gender);
        bot->set_bot_level(level);

        // 初始化 bot（设置属性、装备等）
        bot->init_bot();

        // 随机选择出生房间，尝试最多3次
        mixed room;
        for(int try_count = 0; try_count < 3 && !room; try_count++) {
            string room_path = spawn_rooms[random(sizeof(spawn_rooms))];
            room = load_object(ROOT + "/" + room_path);
            if(!room) {
                werror("[BOTD] 房间加载失败(尝试%d): %s\n", try_count + 1, room_path);
            }
        }

        if(!room) {
            werror("[BOTD] Bot %s 创建失败: 无法加载有效房间\n", bot_id);
            destruct(bot);
            return 0;
        }

        // 移动到房间
        if(!bot->move(room)) {
            werror("[BOTD] Bot 移动失败: %s\n", bot_id);
            destruct(bot);
            return 0;
        }

        werror("[BOTD] Bot 创建成功: %s (%s)\n", bot_id, name_cn);

        // 只有成功移动后才注册到 CONND（模拟登录）
        object dummy_conn = BufferConnection();
        CONND->set_conn(bot, dummy_conn);

        bots[bot_id] = bot;
        return bot;
    };

    // 捕获任何错误
    if(err) {
        werror("[BOTD] 创建 Bot %s 时发生错误: %s\n", bot_id, describe_error(err));
        return 0;
    }
}

/**
 * 检查并重新创建死亡的 Bot
 */
void check_bots()
{
    int alive_count = 0;
    int recreated_count = 0;

    array(string) bot_ids = indices(bots);
    foreach(bot_ids, string bot_id) {
        object bot = bots[bot_id];
        if(!bot || !objectp(bot)) {
            // 重新创建
            int index;
            if(sscanf(bot_id, "bot_%d", index) == 1) {
                create_bot(index);
                recreated_count++;
            }
        } else if(!environment(bot)) {
            // bot 存在但没有环境，重新移动
            string room_path = spawn_rooms[random(sizeof(spawn_rooms))];
            object room = load_object(ROOT + "/" + room_path);
            if(room) {
                bot->move(room);
                // 确保连接还在
                if(!CONND->query_conn(bot)) {
                    object dummy_conn = BufferConnection();
                    CONND->set_conn(bot, dummy_conn);
                }
                alive_count++;
            }
        } else {
            // 确保 bot 仍然在 CONND 中注册
            if(!CONND->query_conn(bot)) {
                object dummy_conn = BufferConnection();
                CONND->set_conn(bot, dummy_conn);
            }
            alive_count++;
        }
    }

    // 继续检查
    call_out(check_bots, 300);

    // werror("[BOTD] Bot 检查完成: 存活 %d, 重建 %d\n", alive_count, recreated_count);
}

/**
 * 获取所有 Bot 对象（用于在线用户显示）
 */
array(object) get_bot_users()
{
    array(object) result = ({});

    array(string) bot_ids = indices(bots);
    foreach(bot_ids, string bot_id) {
        object bot = bots[bot_id];
        if(bot && objectp(bot) && environment(bot)) {
            result += ({ bot });
        }
    }

    return result;
}

/**
 * 获取 Bot 信息
 */
mapping query_bot(string bot_id)
{
    if(!bots[bot_id] || !objectp(bots[bot_id]))
        return 0;

    object bot = bots[bot_id];
    return ([
        "id": bot_id,
        "name_cn": bot->query_name_cn(),
        "gender": bot->query_gender(),
        "level": bot->query_level(),
        "room": file_name(environment(bot)) - ROOT,
    ]);
}

/**
 * 获取所有 Bot 信息
 */
mapping query_all_bots()
{
    mapping result = ([]);

    array(string) bot_ids = indices(bots);
    foreach(bot_ids, string bot_id) {
        object bot = bots[bot_id];
        if(bot && objectp(bot)) {
            result[bot_id] = query_bot(bot_id);
        }
    }

    return result;
}

/**
 * 获取 Bot 统计
 */
mapping query_bot_stats()
{
    int total = sizeof(bots);
    int alive = 0;
    int dead = 0;

    array(string) bot_ids = indices(bots);
    foreach(bot_ids, string bot_id) {
        object bot = bots[bot_id];
        if(bot && objectp(bot) && environment(bot))
            alive++;
        else
            dead++;
    }

    return ([
        "total": total,
        "alive": alive,
        "dead": dead,
    ]);
}

/**
 * 重新加载所有 Bot
 */
void reload_bots()
{
    // 清除现有 bot
    array(string) bot_ids = indices(bots);
    foreach(bot_ids, string bot_id) {
        object bot = bots[bot_id];
        if(bot && objectp(bot)) {
            // 清理连接
            CONND->erase_conn(bot);
            destruct(bot);
        }
    }
    bots = ([]);

    // 重新初始化
    init_bots();
}

/**
 * 让某个 Bot 说话
 */
void bot_say(string bot_id, string msg)
{
    if(!bots[bot_id] || !objectp(bots[bot_id]))
        return;

    object bot = bots[bot_id];
    object env = environment(bot);

    if(env) {
        // 向房间中所有对象发送消息
        foreach(all_inventory(env), object ob) {
            if(ob && functionp(ob->tell_object))
                ob->tell_object(bot->query_name_cn() + "说道: " + msg + "\n");
        }
    }
}

/**
 * 让所有 Bot 随机说话
 */
void random_bot_chat()
{
    array(object) alive_bots = get_bot_users();
    if(sizeof(alive_bots) == 0)
        return;

    // 随机选择几个 bot 说话
    int count = random(5) + 1;
    for(int i = 0; i < count; i++) {
        object bot = alive_bots[random(sizeof(alive_bots))];
        if(bot && environment(bot)) {
            // 使用 bot 自带的聊天回复
            string msg = bot->query_words();
            object env = environment(bot);
            if(env) {
                // 向房间中所有对象发送消息
                foreach(all_inventory(env), object ob) {
                    if(ob && functionp(ob->tell_object))
                        ob->tell_object(bot->query_name_cn() + "说道: " + msg);
                }
            }
        }
    }
}
