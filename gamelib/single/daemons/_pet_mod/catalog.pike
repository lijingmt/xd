/** 山海异兽资料与平衡常量。 */

#ifndef XIAND_PET_CATALOG_PIKE
#define XIAND_PET_CATALOG_PIKE

private mapping(string:mapping(string:mixed)) shanhai_catalog = ([
	"dangkang":([
		"name":"当康","icon":"🐗","family":"土","role":"守护",
		"origin":"钦山瑞兽，形似有牙之豕；古籍记其现世为丰穰之兆。",
		"skill":"丰穰守心","basic_attack":"獠牙拱","boss":0,"exchange":1,
		"skill_sets":({
			({"丰穰守心","厚土相护","谷熟无忧"}),
			({"丰穰守心","山野寻踪","安仓定念"}),
			({"丰穰守心","沃野回春","守成之志"}),
		}),
	]),
	"lushu":([
		"name":"鹿蜀","icon":"🦓","family":"木","role":"疗愈",
		"origin":"招摇山瑞兽，马身白首、虎文赤尾，以和鸣与亲缘见称。",
		"skill":"和鸣回春","basic_attack":"蹄声踏","boss":0,"exchange":1,
		"skill_sets":({
			({"和鸣回春","赤尾安神","同心相守"}),
			({"和鸣回春","白首清音","林息绵长"}),
			({"和鸣回春","虎文护生","相携远行"}),
		}),
	]),
	"wenyaoyu":([
		"name":"文鳐鱼","icon":"🐟","family":"水","role":"灵息",
		"origin":"泰器山异鱼，鱼身鸟翼、白首赤喙，夜间飞渡西海与东海。",
		"skill":"夜渡回澜","basic_attack":"赤喙啄","boss":0,"exchange":1,
		"skill_sets":({
			({"夜渡回澜","苍文聚灵","鸾音引潮"}),
			({"夜渡回澜","双海巡游","飞翼逐浪"}),
			({"夜渡回澜","清波涤念","赤喙鸣风"}),
		}),
	]),
	"bifang":([
		"name":"毕方","icon":"🔥","family":"火","role":"强攻",
		"origin":"一足神鸟，青羽赤文；其火性在万灵裂隙中化为试炼。",
		"skill":"独足炎翎","basic_attack":"焰羽掠","boss":0,"exchange":1,
		"skill_sets":({
			({"独足炎翎","青焰掠空","赤文灼阵"}),
			({"独足炎翎","离火照夜","单翼回旋"}),
			({"独足炎翎","炎羽守誓","清啸退厄"}),
		}),
	]),
	"zheng":([
		"name":"狰","icon":"🐆","family":"金","role":"强攻",
		"origin":"章莪山异兽，赤豹之形，五尾一角，鸣声如击石。",
		"skill":"击石裂锋","basic_attack":"赤影扑","boss":0,"exchange":1,
		"skill_sets":({
			({"击石裂锋","五尾连袭","独角破势"}),
			({"击石裂锋","赤影伏击","金声镇胆"}),
			({"击石裂锋","章莪巡猎","豹纹藏锋"}),
		}),
	]),
	"mengji":([
		"name":"孟极","icon":"🐈","family":"金","role":"迅捷",
		"origin":"北山异兽，形似豹而身有文，善于潜伏与辨察先机。",
		"skill":"伏影先机","basic_attack":"潜影袭","boss":0,"exchange":1,
		"skill_sets":({
			({"伏影先机","雪纹疾步","静息藏踪"}),
			({"伏影先机","豹跃追风","先声夺隙"}),
			({"伏影先机","北山夜察","敛锋待时"}),
		}),
	]),
	"huan":([
		"name":"讙","icon":"🐱","family":"木","role":"守护",
		"origin":"翼望山异兽，野猫之形，独目三尾，以奇声御凶。",
		"skill":"百声御凶","basic_attack":"伏啸震","boss":0,"exchange":1,
		"skill_sets":({
			({"百声御凶","独目照邪","三尾结界"}),
			({"百声御凶","异响清心","翼望守夜"}),
			({"百声御凶","灵尾回护","静听危声"}),
		}),
	]),
	"jiuyihu":([
		"name":"九尾狐","icon":"🦊","family":"灵","role":"灵息",
		"origin":"青丘九尾灵狐，善察人心与虚实；本作只采用古籍意象原创演绎。",
		"skill":"青丘灵梦","basic_attack":"灵尾缠","boss":1,"exchange":0,
		"skill_sets":({
			({"青丘灵梦","九尾流光","月下听心"}),
			({"青丘灵梦","幻境回响","灵狐引路"}),
			({"青丘灵梦","青丘守约","九影归一"}),
		}),
	]),
	"jiao":([
		"name":"狡","icon":"🐕","family":"土","role":"守护",
		"origin":"玉山异兽，犬形豹文而具角，古籍亦记其出现与丰穰相应。",
		"skill":"玉山镇守","basic_attack":"守吠冲","boss":0,"exchange":1,
		"skill_sets":({
			({"玉山镇守","豹文护阵","灵角定心"}),
			({"玉山镇守","丰年之兆","犬影巡山"}),
			({"玉山镇守","玉石无移","守境回声"}),
		}),
	]),
	"chenghuang":([
		"name":"乘黄","icon":"🦌","family":"灵","role":"疗愈",
		"origin":"白民之国瑞兽，狐形而背生角，传说乘之可以延年。",
		"skill":"延年清辉","basic_attack":"灵光抚","boss":0,"exchange":1,
		"skill_sets":({
			({"延年清辉","背角流霞","白民长歌"}),
			({"延年清辉","瑞步生风","清辉护命"}),
			({"延年清辉","长生不息","乘云远游"}),
		}),
	]),
	"tiangou":([
		"name":"天狗","icon":"🐺","family":"金","role":"守护",
		"origin":"阴山异兽，狸形白首，古籍记其声与御凶之能。",
		"skill":"白首辟凶","basic_attack":"吞月咬","boss":0,"exchange":1,
		"skill_sets":({
			({"白首辟凶","阴山巡夜","警声破妄"}),
			({"白首辟凶","灵嗅追迹","守门伏邪"}),
			({"白首辟凶","月影护身","远啸安魂"}),
		}),
	]),
	"fuzhu":([
		"name":"夫诸","icon":"🦌","family":"水","role":"守护",
		"origin":"敖岸山四角白鹿，行过水泽时能察觉潮汐与洪流征兆。",
		"skill":"四角澄澜","basic_attack":"清蹄踏","boss":0,"exchange":1,
		"skill_sets":({
			({"四角澄澜","白鹿巡汜","水镜护心"}),
			({"四角澄澜","潮痕听流","踏浪归湾"}),
			({"四角澄澜","四方定水","雪影守岸"}),
		}),
	]),
	"qinggeng":([
		"name":"青耕","icon":"🐦","family":"木","role":"疗愈",
		"origin":"堇理山青色瑞鸟，和鸣可安定疾疫中的人心与呼吸。",
		"skill":"青羽祓疫","basic_attack":"清翎拂","boss":0,"exchange":1,
		"skill_sets":({
			({"青羽祓疫","堇山和鸣","嘉木生息"}),
			({"青羽祓疫","清翎巡风","听息辨症"}),
			({"青羽祓疫","百草回青","守心无疫"}),
		}),
	]),
	"dijiang":([
		"name":"帝江","icon":"🟥","family":"风","role":"迅捷",
		"origin":"天山神鸟，赤身六足四翼，以无相舞步穿过云间罅隙。",
		"skill":"浑天振翼","basic_attack":"赤翼旋","boss":0,"exchange":1,
		"skill_sets":({
			({"浑天振翼","六足踏音","四翼连环"}),
			({"浑天振翼","无相舞步","云罅闪身"}),
			({"浑天振翼","天山回响","混元归序"}),
		}),
	]),
	"feifei":([
		"name":"朏朏","icon":"🐈","family":"灵","role":"灵息",
		"origin":"霍山白尾异兽，形似野猫，其轻鸣能安抚离愁与郁结。",
		"skill":"忘忧灵息","basic_attack":"白尾摇","boss":0,"exchange":1,
		"skill_sets":({
			({"忘忧灵息","白尾安念","霍山清梦"}),
			({"忘忧灵息","轻鸣听心","雪足寻归"}),
			({"忘忧灵息","离愁化露","一念澄明"}),
		}),
	]),
	"kui":([
		"name":"夔","icon":"🐂","family":"雷","role":"强攻",
		"origin":"流波山雷兽，苍身如牛而独足，出入水则风雨、声如雷。",
		"skill":"流波震雷","basic_attack":"雷震踏","boss":1,"exchange":0,
		"skill_sets":({
			({"流波震雷","独足撼海","苍雷惊潮"}),
			({"流波震雷","风雨同来","雷音破阵"}),
			({"流波震雷","东海回声","一跃山倾"}),
		}),
	]),
	"yingzhao":([
		"name":"英招","icon":"🐎","family":"风","role":"迅捷",
		"origin":"槐江山神兽，马身人面、虎文鸟翼，巡游四海。",
		"skill":"四海巡风","basic_attack":"风驰踏","boss":1,"exchange":0,
		"skill_sets":({
			({"四海巡风","虎文振翼","槐江越阵"}),
			({"四海巡风","天门疾驰","羽影连环"}),
			({"四海巡风","山海巡察","风息护途"}),
		}),
	]),
	"qiongqi":([
		"name":"穷奇","icon":"🐅","family":"异","role":"强攻",
		"origin":"山海古籍中的凶兽之一，本作将其化为可封印、可理解的裂隙强敌。",
		"skill":"逆风裂界","basic_attack":"凶噬扑","boss":1,"exchange":0,
		"skill_sets":({
			({"逆风裂界","凶纹怒啸","穷途反击"}),
			({"逆风裂界","异兽威压","破序之爪"}),
			({"逆风裂界","止戈封心","归契山海"}),
		}),
	]),
	"yinglong":([
		"name":"应龙","icon":"🐉","family":"水","role":"灵息",
		"origin":"大荒有翼之龙，通水泽与云雨；在裂隙轮替中象征秩序重归。",
		"skill":"云雨应时","basic_attack":"龙爪攫","boss":1,"exchange":0,
		"skill_sets":({
			({"云雨应时","翼龙行水","大荒回澜"}),
			({"云雨应时","苍云布泽","雨师同律"}),
			({"云雨应时","应时而动","龙翼镇潮"}),
		}),
	]),
	"luanniao":([
		"name":"鸾鸟","icon":"🕊️","family":"灵","role":"疗愈",
		"origin":"女床山五采瑞鸟，古籍记其现世象征安宁；本作以守护灵契作原创演绎。",
		"skill":"回生羽","basic_attack":"灵羽回春","boss":0,"exchange":0,"hidden":1,
		"skill_sets":({
			({"回生羽","五采安魂","鸾音护命"}),
			({"回生羽","女床清鸣","灵羽回光"}),
			({"回生羽","瑞羽守契","长空归心"}),
		}),
	]),
]);

private array(string) starter_species = ({
	"dangkang","lushu","wenyaoyu",
});

private array(string) rift_boss_species = ({
	"kui","yingzhao","qiongqi","yinglong","jiuyihu",
});

array(string) query_all_species()
{
	return indices(shanhai_catalog);
}

array(string) query_starter_species()
{
	return starter_species+({});
}

array(string) query_rift_boss_species()
{
	return rift_boss_species+({});
}

mapping(string:mapping(string:mixed)) query_pet_catalog()
{
	return copy_value(shanhai_catalog);
}

mapping(string:mixed) query_pet_species(string species)
{
	if(!species || !shanhai_catalog[species])
		return ([]);
	return copy_value(shanhai_catalog[species]);
}

int is_valid_pet_species(string species)
{
	return !!shanhai_catalog[species];
}

string query_pet_species_polarity(string species)
{
	string family;
	if(!shanhai_catalog[species])
		return "";
	family = (string)shanhai_catalog[species]["family"];
	if(search(({"水","木","土","灵"}),family)!=-1)
		return "yin";
	return "yang";
}

string query_pet_polarity(mapping pet)
{
	if(!mappingp(pet))
		return "";
	if(mappingp(pet["fusion"]) &&
	   search(({"yin","yang"}),
		(string)pet["fusion"]["polarity"])!=-1)
		return (string)pet["fusion"]["polarity"];
	return query_pet_species_polarity((string)pet["species"]);
}

string query_pet_polarity_name(string polarity)
{
	return polarity=="yin" ? "阴" : (polarity=="yang" ? "阳" : "未定");
}

string query_weekly_boss_species(void|int at_time)
{
	int now = at_time || time();
	int index = (now/604800)%sizeof(rift_boss_species);
	return rift_boss_species[index];
}

int query_pet_level_max(void|object player)
{
	int level_max = PET_LEVEL_MAX;
	if(player && functionp(player->query_level))
		level_max = (int)player->query_level();
	if(level_max<1)
		level_max = 1;
	if(level_max>PET_LEVEL_MAX)
		level_max = PET_LEVEL_MAX;
	return level_max;
}

int query_pet_bond_max()
{
	return PET_BOND_MAX;
}

int query_pet_exchange_marks()
{
	return PET_EXCHANGE_MARKS;
}

int query_pet_fragment_hatch_cost()
{
	return PET_FRAGMENT_HATCH_COST;
}

int query_pet_cosmetic_dust_cost()
{
	return PET_COSMETIC_DUST_COST;
}

int query_pet_pve_fragment_daily_cap()
{
	return PET_PVE_FRAGMENT_DAILY_CAP;
}

#endif
