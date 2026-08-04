#include <command.h>
#include <gamelib/include/gamelib.h>

private string material_detail(object me,string skill_name,int recipe_id,
	int target_level,int amount)
{
	string s = "";
	mapping(string:array) base = ARTISAND->query_recipe_materials(skill_name,
		recipe_id);
	mapping(string:int) needs = ARTISAND->query_required_materials(skill_name,
		recipe_id,amount,target_level);
	foreach(sort(indices(needs)),string item_name){
		array data = base[item_name];
		string name_cn = item_name;
		int have = ARTISAND->query_material_count(me,item_name);
		if(arrayp(data) && sizeof(data)>0)
			name_cn = (string)data[0];
		s += name_cn+" × "+(string)needs[item_name]+"（现有"+
			(string)have+"）\n";
	}
	return s;
}

int main(string|zero arg)
{
	object me = this_player();
	string s = "【大师高阶制作】\n";
	string skill_name = "";
	int target_level = 0;
	int recipe_id = 0;
	int amount = 0;
	int parsed;
	array(int) recipes;
	ARTISAND->initialize_player(me);
	parsed = sscanf(arg,"%s %d %d %d",skill_name,target_level,recipe_id,amount);
	if(parsed<2 || ARTISAND->query_master_specialty(me)!=skill_name){
		s += "高阶制作参数无效，或当前大师专精不匹配。\n";
	}
	else if(target_level<80 || target_level%20!=0 ||
	   target_level>me->query_level()){
		s += "目标等级必须是80级起、每20级一阶，且不能超过人物等级。\n";
	}
	else if(parsed==2){
		recipes = ARTISAND->query_high_recipe_ids(me,skill_name);
		if(!sizeof(recipes))
			s += "你还没有学会65级以上的可升阶配方。\n";
		else{
			s += "选择要升阶为"+(string)target_level+"级的配方：\n";
			foreach(recipes,int one_id){
				int can_make = ARTISAND->query_makeable_amount(me,
					skill_name,one_id,target_level);
				s += "["+ARTISAND->query_recipe_name_cn(skill_name,one_id)+
					":artisan_master_craft "+skill_name+" "+
					(string)target_level+" "+(string)one_id+" 0]";
				if(can_make>0)
					s += "（可制作"+(string)can_make+"件）";
				s += "\n";
			}
		}
	}
	else if(!ARTISAND->has_recipe(me,skill_name,recipe_id) ||
	   ARTISAND->query_recipe_item_level(skill_name,recipe_id)<65){
		s += "你没有学会这张可升阶配方。\n";
	}
	else if(amount==0){
		int multiplier = ARTISAND->query_master_material_multiplier(target_level);
		s += ARTISAND->query_recipe_name_cn(skill_name,recipe_id)+
			" → "+(string)target_level+"级\n";
		s += "原料倍率："+(string)multiplier+"倍\n--------\n";
		s += material_detail(me,skill_name,recipe_id,target_level,1);
		s += "[制作1件:artisan_master_craft "+skill_name+" "+
			(string)target_level+" "+(string)recipe_id+" 1]";
		if(ARTISAND->query_makeable_amount(me,skill_name,recipe_id,
		   target_level)>=5)
			s += "|[制作5件:artisan_master_craft "+skill_name+" "+
				(string)target_level+" "+(string)recipe_id+" 5]";
		s += "\n";
	}
	else{
		mapping result = ARTISAND->craft_equipment(me,skill_name,
			recipe_id,amount,target_level);
		s += (string)result["message"]+"\n";
		if((int)result["ok"] && arrayp(result["items"])){
			array items = result["items"];
			foreach(items,object item){
				if(item)
					s += "[查看"+item->query_name_cn()+":inv_other "+
						file_name(item)+"]\n";
			}
		}
	}
	s += "[返回同阶配方:artisan_master_craft "+skill_name+" "+
		(string)target_level+"]|[返回百工坊:artisan]|[返回游戏:look]\n";
	write(s);
	return 1;
}
