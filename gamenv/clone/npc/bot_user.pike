/**
 * ========================================================================
 * Bot User - 假用户NPC
 * ========================================================================
 *
 * 直接继承 user 类，拥有所有玩家属性：
 * - 随机走动
 * - 自动装备
 * - 友好聊天回复
 * - 显示在在线用户列表中
 *
 * ========================================================================
 */

#include <globals.h>
#include <wapmud2/include/wapmud2.h>
#include <gamenv/include/gamenv.h>

// 直接继承 user 类，拥有所有玩家属性
inherit ROOT "/gamenv/clone/user";

// CONND 定义
#define CONND ((object)(ROOT + "/pikenv/connd.pike"))

// Bot 标记
private int is_bot_user = 1;

// 友好鼓励语料
private static array(string) friendly_chats = ({
    "你好，一起努力练功吧！",
    "加油练功，坚持就是胜利！",
    "今天也要努力修炼啊。",
    "功夫不负有心人，继续努力！",
    "我也要加油练功了。",
    "大家一起来修炼吧。",
    "练功虽然辛苦，但很有趣。",
    "每天进步一点点，积少成多。",
    "相信自己，一定能成为高手！",
    "这里是个练功的好地方。",
    "一起加油，共同进步！",
    "修炼之路漫漫，贵在坚持。",
    "今天状态不错，继续练功！",
    "看到大家这么努力，我也要加油了。",
    "游戏里的世界很精彩，慢慢探索。",
    "练功要循序渐进，不能着急。",
    "大家加油，我也要去修炼了。",
    "今天收获不小，很开心。",
    "继续努力，早日成为绝世高手！",
    "修炼需要耐心，慢慢来。",
    "祝愿大家武艺精进！",
});

// 移动间隔计数
private int move_interval = 0;

// Bot 配置（使用私有变量避免触发重载运算符）
private string _bot_id;
private int _bot_level;
private string _bot_gender;
private string _bot_name_cn;

/**
 * 创建 Bot
 */
void create()
{
    // 先调用父类的 create
    ::create();

    // 先设置一个默认名字，防止为空
    name = "bot_" + random(10000);
    name_cn = "路人" + name;
    gender = (random(2) == 0) ? "male" : "female";

    // 移动间隔 - 初始随机，让不同bot有不同节奏
    move_interval = 3 + random(10);  // 3-13秒后开始第一次移动

    // 启动心跳
    set_heart_beat(1);
}

/**
 * 初始化 Bot 属性（在所有 setter 调用后由 daemon 调用）
 */
void init_bot()
{
    // 使用已设置的私有变量
    string bot_id = _bot_id || name;
    int bot_level = _bot_level || random(150) + 10;  // 随机等级 10-160
    string bot_gender = _bot_gender || ((random(2) == 0) ? "male" : "female");  // 随机性别
    string bot_name_cn = _bot_name_cn || name_cn;

    // 设置名字
    name = bot_id;
    name_cn = bot_name_cn;
    gender = bot_gender;

    // 注册到 living_names，使 find_player() 能找到 bot
    set_living_name(name);

    // 设置等级相关属性
    set_daoheng_for_level(bot_level);

    // 设置门派和称号
    setup_school_and_rank(bot_level);

    // 设置描述（包含随机年龄）
    setup_description();

    // 装备系统
    equip_bot();
}

/**
 * 根据等级设置道行（加入随机性）
 * 终极强化版 - 根骨/修为/属性提高10000倍让假用户成为终极BOSS
 */
void set_daoheng_for_level(int level)
{
    // 道行 = 等级^3 * 1000 * 100 * 100，加入 ±20% 随机波动（提高10000倍）
    int base_daoheng = level * level * level * 1000 * 100 * 100;
    daoheng = base_daoheng + random(base_daoheng / 5) - random(base_daoheng / 5);
    if(daoheng < 1000) daoheng = 1000;

    // 潜能（加入随机性）
    potential = level * 1000 * 100 * 100 + random(level * 500 * 100 * 100);

    // 杀气（随机）
    bellicosity = random(level * 10 * 100 * 100);

    // 设置进阶等级（1-9随机）
    // /renascence/cur_inbeing_flag: 0=未进阶, 1=先天一阶, ..., 9=先天九阶
    this_object()["/renascence/cur_inbeing_flag"] = random(10);  // 0-9随机

    // ========== 终极强化属性 ==========
    // 生命值（提高 1000倍）
    jing_max = level * 500000 + random(level * 200000);
    jing = jing_max;

    // 内力（提高 1000倍）
    qi_max = level * 300000 + random(level * 100000);
    qi = qi_max;

    // 精神（提高 1000倍）
    shen_max = level * 200000 + random(level * 50000);
    shen = shen_max;

    // 法力（提高 1000倍）
    mana_max = level * 100000 + random(level * 50000);
    mana = mana_max;

    // 食物和水
    food_max = 1000;
    food = food_max;
    water_max = 1000;
    water = water_max;

    // ========== 根骨（终极强化 - 1亿+）==========
    // 根骨提供攻击加成，根据等级和转阶计算
    int base_gengu = level * 10000 * 100 + random(level * 5000 * 100);
    gengu = base_gengu;

    // ========== 战斗属性加成（终极强化）==========
    // 攻击力、招架、闪避属性（提高10000倍）
    int base_combat = level * 200 * 100 + random(level * 100 * 100);
    this_object()["/plus/attrib/attack"] = base_combat;
    this_object()["/plus/attrib/parry"] = base_combat / 2 + random(level * 50 * 100);
    this_object()["/plus/attrib/dodge"] = base_combat / 2 + random(level * 50 * 100);
}

/**
 * 设置描述
 */
void setup_description()
{
    // 容貌
    appearance = (int)pow(daoheng, 1.0/3) * 10 + random(50);

    // 年龄（16-60岁）
    set_age(16 + random(44));

    // 描述
    desc = "这是一个" + name_cn + "，看起来" +
           (gender == "male" ? "英俊潇洒" : "美丽动人") +
           "的样子。\n";
}

/**
 * 设置门派和称号
 */
void setup_school_and_rank(int level)
{
    // 门派列表
    array(string) schools = ({
        "shaolin",      // 少林
        "wudangpai",    // 武当
        "emei",         // 峨眉
        "huashan",      // 华山
        "kongdong",     // 崆峒
        "kunlun",       // 昆仑
        "xingxiupai",   // 星宿
        "shenlongjiao", // 神龙教
        "tianpeng",     // 天蓬
        "linjiugong",   // 临济宫
    });

    // 称号列表（按等级）
    array(string) low_ranks =({"弟子","门人","徒儿",});
    array(string) mid_ranks =({"师兄","师姐","长老",});
    array(string) high_ranks =({"掌门","宗师","尊者",});

    // 随机选择门派
    school = schools[random(sizeof(schools))];

    // 根据等级选择称号
    if(level < 50)
        rank = low_ranks[random(sizeof(low_ranks))];
    else if(level < 100)
        rank = mid_ranks[random(sizeof(mid_ranks))];
    else
        rank = high_ranks[random(sizeof(high_ranks))];

    // 设置 generation (代数，0表示本代)
    generation = 0;
}

/**
 * 装备 Bot - 根据等级随机装备（从头到脚完整套装）
 */
void equip_bot()
{
    int level = (int)pow(daoheng, 1.0/3);

    // 女娲套装（完整从头到脚）- 高等级bot使用
    array(string) nvwa_set = ({
        "nvwa/nvwazhijia",        // 盔甲：女娲之甲
        "nvwa/nvwazhiguan",       // 头盔：女娲之冠 (type=head)
        "nvwa/nvwazhifeng",       // 头饰：发风 (weapon, sword)
        "nvwa/nvwaxianglian",     // 项链：项链 (type=necklace)
        "nvwa/nvwazhishou",       // 手套：女娲之手 (weapon, unarmed)
        "nvwa/nvwazhibaozhu",     // 手镯：宝珠 (type=hands)
        "nvwa/nvwazhizhihuan",    // 戒指：指环 (type=finger)
        "nvwa/nvwazhihuadai",     // 腰带：花带 (type=waist)
        "nvwa/nvwazhiren",        // 披风：缎带 (weapon, blade)
        "nvwa/nvwazhipifeng",     // 披风：披风 (type=armor)
        "nvwa/nvwazhihutui",      // 护腿：护腿 (type=trousers)
        "nvwa/nvwazhixue",        // 鞋子：女娲之靴 (type=boots)
    });

    // 武器列表（按等级分组）
    array(string) low_weapons = ({
        "dao/gangdao", "dao/tongdao", "dao/jiedao", "dao/zhongdao",
        "dao/miandao", "dao/yindao", "dao/zhudao", "dao/zimangren",
        "jian/baigujian",
    });

    array(string) mid_weapons = ({
        "dao/hanbingren", "dao/wuqingdao", "dao/lengyue", "dao/xinyuedao",
        "dao/ranmudao", "dao/xiuluodao", "dao/ziluodao", "dao/honglianxieren",
        "jian/hanbingjian", "jian/tianquan",
    });

    array(string) high_weapons = ({
        "dao/baizhanbaodao", "dao/chiyandao", "dao/lietiandao", "dao/lengyindao",
        "dao/huangjinshuangrao", "dao/jinhuandadao", "dao/yaodaogoutu",
        "dao/yemodao", "dao/yuanyuewandao",
        "jian/anyangjian", "jian/fumojian", "jian/tianpeng",
    });

    // 护甲列表 (type=cloth)
    array(string) low_armors = ({
        "cloth/buyi", "cloth/pijia", "cloth/pjia", "cloth/epijia",
        "cloth/tengjia", "cloth/mopizhanjia", "cloth/hupijia", "cloth/suozijia",
    });

    array(string) mid_armors = ({
        "cloth/jinsijia", "cloth/mangpijia", "cloth/jinsiruanjia",
        "cloth/guikejia", "cloth/haishepijia", "cloth/longgujia",
        "cloth/tianlingjia", "cloth/tielianjiasha", "cloth/yinninpifeng",
    });

    array(string) high_armors = ({
        "cloth/longlinjia", "cloth/longlingjia", "cloth/jinlianjiasha",
        "cloth/fengyunpifeng", "cloth/shenxingyi", "cloth/xueyupifeng",
        "cloth/yinhuchang", "cloth/yulianyi", "cloth/tonglianjiasha",
        "cloth/xuanwuzhanpao",
    });

    // 头部装备 (type=head)
    array(string) head_items = ({
        "head/yinnimianju",
    });

    // 鞋子 (type=boots)
    array(string) boots_items = ({
        "shoes/buxue",
    });

    // 戒指 (type=finger)
    array(string) ring_items = ({
        "ring/bojinring", "ring/goldring", "ring/leijie",
        "ring/mijie", "ring/zuanjie",
    });

    // 首先始终装备基础装备（不管是否使用女娲套装）
    // 根据等级选择武器列表
    array(string) weapon_list;
    if(level < 50)
        weapon_list = low_weapons;
    else if(level < 100)
        weapon_list = mid_weapons;
    else
        weapon_list = high_weapons;

    // 随机选择 1-2 把武器
    int weapon_count = 1 + random(2);
    for(int i = 0; i < weapon_count && sizeof(weapon_list) > 0; i++) {
        string weapon = weapon_list[random(sizeof(weapon_list))];
        equip_item(weapon);
    }

    // 根据等级选择护甲列表
    array(string) armor_list;
    if(level < 50)
        armor_list = low_armors;
    else if(level < 100)
        armor_list = mid_armors;
    else
        armor_list = high_armors;

    // 随机选择 2-3 件护甲（增加装备数量）
    int armor_count = 2 + random(2);
    for(int i = 0; i < armor_count && sizeof(armor_list) > 0; i++) {
        string armor = armor_list[random(sizeof(armor_list))];
        equip_item(armor);
    }

    // 装备头部（80%概率，提高装备率）
    if(random(10) < 8 && sizeof(head_items) > 0) {
        string head = head_items[random(sizeof(head_items))];
        equip_item(head);
    }

    // 装备鞋子（90%概率，提高装备率）
    if(random(10) < 9 && sizeof(boots_items) > 0) {
        string boots = boots_items[random(sizeof(boots_items))];
        equip_item(boots);
    }

    // 装备戒指（2-3个，增加装备数量）
    int ring_count = 2 + random(2);
    for(int i = 0; i < ring_count && sizeof(ring_items) > 0; i++) {
        string ring = ring_items[random(sizeof(ring_items))];
        equip_item(ring);
    }

    // 高等级bot且转阶等级≥7时，额外尝试女娲套装
    int renais = this_object()["/renascence/cur_inbeing_flag"];
    if(level >= 100 && renais >= 7 && random(2) == 0) {
        foreach(nvwa_set, string item_path) {
            equip_nvwa_item(item_path);
        }
    }

    // 学习技能
    learn_skills(level);
}

/**
 * 装备女娲套装物品
 */
void equip_nvwa_item(string item_path)
{
    string full_path = ROOT + "/gamenv/clone/item/" + item_path;
    mixed err = catch {
        object ob = new(full_path);
        if(ob) {
            ob->move(this_object());
            mixed wear_err = catch {
                wear(ob);
                wield(ob);
            };
            if(wear_err) {
                // 装备失败，可能是技能要求不够，忽略
            }
        }
    };
    if(err) {
        // 创建物品失败，忽略
    }
}

/**
 * 装备单个物品
 */
void equip_item(string item_path)
{
    string full_path = ROOT + "/gamenv/clone/item/" + item_path;
    mixed err = catch {
        object ob = new(full_path);
        if(ob) {
            ob->move(this_object());
            catch {
                wear(ob);
                wield(ob);
            };
        }
    };
}

/**
 * 学习技能 - 仿照真实 NPC 设置
 * 终极强化版 - 技能等级提高10000倍让假用户成为终极BOSS
 */
void learn_skills(int level)
{
    // 初始化 skills_enable 映射
    if(!skills_enable) skills_enable = ([]);

    // 计算技能等级（提高 10000 倍）
    int skill_level = level * 200 * 100;  // 原来是 level * 2，现在是 10000 倍
    if(skill_level < 10) skill_level = 10;
    if(skill_level > 1000000) skill_level = 1000000;  // 提高上限到100万
    int skill_exp = 0;  // 真实 NPC 的技能经验通常是 0

    // 设置基础技能（仿照 xuanbei NPC，等级终极强化）
    skills["unarmed"] = ({skill_level, skill_exp});
    skills["blade"] = ({skill_level, skill_exp});
    skills["sword"] = ({skill_level, skill_exp});
    skills["parry"] = ({skill_level, skill_exp});
    skills["dodge"] = ({skill_level, skill_exp});
    skills["force"] = ({skill_level, skill_exp});

    // 动态创建 blade 和 sword 基础技能对象并添加到 SKILLSD
    // 这样 get_attack_skill() 就能找到这些技能
    add_basic_skill_to_daemon("blade", "基本刀法", "刀是百兵之帅，刀法讲究劈、砍、撩、挂等。");
    add_basic_skill_to_daemon("sword", "基本剑法", "剑是百兵之君，剑法讲究轻灵、飘逸、刚柔并济。");
}

/**
 * 加载基础技能对象并添加到 SKILLSD daemon
 * 技能文件已存在于 gamenv/single/skills/
 */
void add_basic_skill_to_daemon(string skill_name, string skill_name_cn, string skill_desc)
{
    // 首先检查 SKILLSD 中是否已有此技能
    object existing = SKILLSD[skill_name];
    if(existing){
        return;  // 已存在，无需添加
    }

    // 直接从 gamenv/single/skills/ 加载已存在的技能文件
    mixed err = catch {
        string skill_path = ROOT "/gamenv/single/skills/" + skill_name;
        program p = (program)skill_path;
        if(p){
            object skill_ob = new(p);
            SKILLSD->add_skill(skill_ob);
        }
    };
}

/**
 * 重写 get_attack_skill - 处理武器技能
 * blade/sword 技能已通过 learn_skills 添加到 SKILLSD
 */
object get_attack_skill()
{
    string skill;
    // 获取武器技能
    mapping eq = this_object()->equip;
    if(eq && eq["weapon"]){
        skill=eq["weapon"]->skill;
    }
    // 如果没有武器或技能为空，使用 unarmed
    if(skill==0)
        skill="unarmed";

    // 获取技能对象（现在 SKILLSD 应该有 blade/sword 了）
    object basic=SKILLSD[skill];
    if(basic==0 || basic->type!="basic"){
        // 如果找不到指定技能，回退到 unarmed
        skill="unarmed";
        basic=SKILLSD[skill];
        if(basic==0 || basic->type!="basic"){
            return 0;
        }
    }

    // 如果有启用的高级技能，返回高级技能
    mapping se = this_object()->skills_enable;
    if(se && se[skill]){
        return SKILLSD[se[skill]];
    }
    return basic;
}

/**
 * 检查是否已学习技能
 */
int has_skill(string skill_name)
{
    if(!skills) skills = ([]);
    return skills[skill_name] != 0;
}

/**
 * 学习单个技能
 */
void learn_skill(string skill_name)
{
    if(!skills) skills = ([]);
    int skill_level = (int)pow(daoheng, 1.0/3) / 10;
    if(skill_level < 1) skill_level = 1;
    if(skill_level > 200) skill_level = 200;
    int skill_exp = skill_level * skill_level * 100;
    skills[skill_name] = ({skill_level, skill_exp});
}

/**
 * 心跳 - 模拟真人行为（不调用父类心跳避免战斗系统错误）
 */
void heart_beat()
{
    // 不调用父类的 heart_beat，避免触发战斗系统
    // ::heart_beat();

    move_interval--;

    // 随机移动 - 模拟真人行为
    if(move_interval <= 0) {
        // 随机决定行为类型
        int action = random(100);

        if(action < 60) {
            // 60% 概率移动到相邻房间
            random_move();
            // 移动后可能继续移动（模拟赶路）
            if(random(100) < 30) {
                move_interval = 2 + random(5);  // 2-7秒后继续移动
            } else {
                move_interval = 5 + random(20);  // 5-25秒后下一次移动
            }
        } else if(action < 80) {
            // 20% 概率原地停留（模拟休息、看聊天、挂机）
            move_interval = 20 + random(60);  // 20-80秒停留
        } else if(action < 95) {
            // 15% 概率快速连续移动（模拟赶路）
            for(int i = 0; i < 2 + random(3); i++) {
                random_move();
            }
            move_interval = 10 + random(30);  // 10-40秒后休息
        } else {
            // 5% 概率长时间停留（模拟离开键盘）
            move_interval = 60 + random(120);  // 60-180秒停留
        }
    }
}

/**
 * 随机移动 - 模拟真人选择出口
 */
void random_move()
{
    object env = environment(this_object());
    if(!env) {
        return;
    }

    // 获取出口 - query_exits 返回映射格式: ({"direction": "room_path", ...})
    mixed exits = env->query_exits();
    if(!exits || !mappingp(exits)) {
        return;
    }

    // 获取所有方向
    array(string) directions = indices(exits);
    if(sizeof(directions) == 0) {
        return;
    }

    // 模拟真人：有10%概率不移动（犹豫）
    if(random(100) < 10) {
        return;
    }

    // 随机选择一个方向
    string direction = directions[random(sizeof(directions))];

    // 使用 command("leave "+direction) 移动（仿照现有 NPC 的 randomGo 模式）
    command("leave " + direction);
}

/**
 * 聊天回复（玩家对话时触发）
 */
string query_words()
{
    // 如果有任务相关对话，优先返回
    string quest = TASKD->query_words(this_player(), this_object());
    if(quest != "" && quest != 0)
        return quest;

    // 返回友好鼓励的话
    string msg = friendly_chats[random(sizeof(friendly_chats))];
    return msg + "\n";
}

/**
 * 标识为 bot（用于特殊处理）
 */
int is_bot()
{
    return 1;
}

/**
 * 返回空闲时间为0（看起来在线）
 */
int query_idle()
{
    return 0;
}

/**
 * 返回帮派ID（无帮派）
 */
string query_bangid()
{
    return "nobang";
}

/**
 * 战斗胜利时的消息
 */
string query_success_msg()
{
    return "承让了，继续加油练功吧！\n";
}

/**
 * 战斗死亡时的消息
 */
void fight_die()
{
    object env = environment(this_object());
    if(env) {
        tell_room(env, name_cn + "说道: 你好厉害，我还要继续努力练功！\n");
    }
    ::fight_die();
}

/**
 * 设置 Bot ID（由 daemon 调用）
 */
void set_bot_id(string id)
{
    _bot_id = id;
}

/**
 * 设置 Bot 中文名（由 daemon 调用）
 */
void set_bot_name_cn(string nc)
{
    _bot_name_cn = nc;
}

/**
 * 设置 Bot 性别（由 daemon 调用）
 */
void set_bot_gender(string g)
{
    _bot_gender = g;
}

/**
 * 设置 Bot 等级（由 daemon 调用）
 */
void set_bot_level(int level)
{
    _bot_level = level;
}

/**
 * 获取 Bot 等级
 */
int query_level()
{
    return (int)pow(daoheng, 1.0/3);
}

/**
 * 覆盖 save() - Bot 不需要保存到磁盘
 */
void save(void|int autosave)
{
    // Bot 不保存，直接返回
    return;
}

/**
 * 覆盖 remove() - 清理连接
 */
void remove()
{
    // 清理 CONND 连接
    CONND->erase_conn(this_object());
    ::remove();
}
