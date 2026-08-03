/** 灵宠等级、星级、进化阶段与确定性属性。 */

#ifndef XIAND_PET_GROWTH_PIKE
#define XIAND_PET_GROWTH_PIKE

int query_pet_star_max()
{
	return PET_STAR_MAX;
}

int query_pet_star_cost(int current_star)
{
	if(current_star<1 || current_star>=PET_STAR_MAX)
		return 0;
	return 5+current_star*5;
}

int query_pet_evolution_stage(int star)
{
	if(star>=9)
		return 3;
	if(star>=6)
		return 2;
	if(star>=3)
		return 1;
	return 0;
}

string query_pet_evolution_name(int star)
{
	if(star>=PET_STAR_MAX)
		return "真形·圆满";
	switch(query_pet_evolution_stage(star)){
		case 1:
			return "成长体";
		case 2:
			return "觉醒体";
		case 3:
			return "真形体";
		default:
			return "初生体";
	}
}

private mapping(string:int) query_pet_role_base_attributes(string role)
{
	switch(role){
		case "强攻":
			return (["life":1000,"attack":180,"defense":80,
				"spirit":70,"speed":110]);
		case "迅捷":
			return (["life":950,"attack":150,"defense":75,
				"spirit":90,"speed":180]);
		case "疗愈":
			return (["life":1200,"attack":70,"defense":100,
				"spirit":170,"speed":90]);
		case "灵息":
			return (["life":1100,"attack":90,"defense":90,
				"spirit":180,"speed":110]);
		default:
			return (["life":1500,"attack":80,"defense":160,
				"spirit":70,"speed":70]);
	}
}

int query_pet_growth_percent(mapping pet,void|int pvp)
{
	int level;
	int star;
	int bond;
	int evolution;
	int result;
	if(!mappingp(pet))
		return 100;
	level = (int)pet["level"];
	star = (int)pet["star"];
	bond = (int)pet["bond"];
	if(level<1)
		level = 1;
	if(level>PET_LEVEL_MAX)
		level = PET_LEVEL_MAX;
	if(star<1)
		star = 1;
	if(star>PET_STAR_MAX)
		star = PET_STAR_MAX;
	if(bond<1)
		bond = 1;
	if(bond>PET_BOND_MAX)
		bond = PET_BOND_MAX;
	evolution = query_pet_evolution_stage(star);
	result = 100+(level-1)+(star-1)*4+(bond-1)*3+evolution*5;
	if(mappingp(pet["fusion"]))
		result += (int)pet["fusion"]["growth_bonus"];
	if(pvp)
		result = 100+(result-100)*20/100;
	return result;
}

mapping(string:int) query_pet_attributes(mapping pet)
{
	string species;
	string role;
	mapping info;
	mapping(string:int) base;
	mapping(string:int) result = ([]);
	int level;
	int star;
	int bond;
	int evolution;
	int scale;
	int power;
	if(!mappingp(pet))
		return result;
	species = (string)pet["species"];
	info = shanhai_catalog[species];
	if(!info)
		return result;
	role = (string)info["role"];
	base = query_pet_role_base_attributes(role);
	level = (int)pet["level"];
	star = (int)pet["star"];
	bond = (int)pet["bond"];
	if(level<1)
		level = 1;
	if(level>PET_LEVEL_MAX)
		level = PET_LEVEL_MAX;
	if(star<1)
		star = 1;
	if(star>PET_STAR_MAX)
		star = PET_STAR_MAX;
	if(bond<1)
		bond = 1;
	if(bond>PET_BOND_MAX)
		bond = PET_BOND_MAX;
	evolution = query_pet_evolution_stage(star);
	scale = 100+(level-1)*8+(star-1)*25+(bond-1)*20+
		evolution*50;
	foreach(indices(base),string attribute){
		int percent = 100;
		if(mappingp(pet["fusion"]) &&
		   mappingp(pet["fusion"]["attribute_percent"]))
			percent = (int)pet["fusion"]["attribute_percent"][attribute];
		if(percent<100)
			percent = 100;
		result[attribute] = base[attribute]*scale/100*percent/100;
	}
	power = result["life"]/10+result["attack"]*3+
		result["defense"]*3+result["spirit"]*3+
		result["speed"]*2;
	result["power"] = power;
	return result;
}

private mapping(string:mixed) enrich_pet_view(mapping pet)
{
	mapping result = copy_value(pet);
	int star = (int)result["star"];
	if(star<1)
		star = 1;
	result["star"] = star;
	result["evolution"] = query_pet_evolution_stage(star);
	result["evolution_name"] = query_pet_evolution_name(star);
	result["attributes"] = query_pet_attributes(result);
	result["power"] = (int)result["attributes"]["power"];
	result["growth_percent"] = query_pet_growth_percent(result,0);
	result["pvp_growth_percent"] = query_pet_growth_percent(result,1);
	result["polarity"] = query_pet_polarity(result);
	result["polarity_name"] = query_pet_polarity_name(
		(string)result["polarity"]);
	return result;
}

#endif
