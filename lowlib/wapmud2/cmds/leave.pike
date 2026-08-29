#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
#define LOGICALZONED ((object)(ROOT "/gamelib/single/daemons/logical_zoned.pike"))

// A follower cannot be commanded after the leader object has been retired on
// another worker. Clear both sides explicitly instead of leaving a permanent
// ghost-follow relation; players may follow again after they meet on one node.
void detach_worker_move_followers(object leader,object old_env)
{
	if(!leader)
		return;
	if(arrayp(leader->follow_me)){
		foreach(leader->follow_me,string follower_name){
			object follower = find_player(follower_name);
			if(follower && environment(follower)==old_env){
				follower->follow = "_none";
				tell_object(follower,"目标跨越了地图节点，自动跟随已安全解除。\n");
			}
		}
		leader->follow_me = ({});
	}
	if(leader->follow && leader->follow!="_none"){
		object followed = find_player((string)leader->follow);
		if(followed && arrayp(followed->follow_me))
			followed->follow_me -= ({(string)leader->query_name()});
		leader->follow = "_none";
	}
}

int main(string|zero arg)
{
	object me = this_player();
	// 登录阶段的 LOW_USER 没有 DBASE 路径存储；它仍能解析到本命令，
	// 所以必须在访问 /tmp/atk_ctime 以及房间出口前确认是完整游戏角色。
	if(!me || !stringp(arg) || sizeof(arg)==0 ||
	   !functionp(me->m_delete_foruser) || !functionp(me->query_level))
		return 0;
	if(!me->is("npc") && me->query_autofight()=="disable"){
		//leave操作，也触发外挂监控，不然太猖獗
		if(!me["/tmp/atk_ctime"])
			me["/tmp/atk_ctime"] = (System.Time()->usec_full)/1000;
		else{
			if( ((System.Time()->usec_full)/1000 - me["/tmp/atk_ctime"]) <= 1500 ){
				werror("-------- player["+me->name+"] leave difftime<=1000 --------\n");
				if(!me["/tmp/wg_times"]) me["/tmp/wg_times"] = 1;
				else me["/tmp/wg_times"]++;
			}
			else{
				me["/tmp/atk_ctime"] = (System.Time()->usec_full)/1000;
			}
		}

		int entry_flag = 0;
		//attack/use_perform记录超过300次连击，判定进入调用
		//暂时设置成1000，等服务器负载上去了再调整
		if(me["/tmp/wg_times"]>=1000) entry_flag = 1;
		else entry_flag = 0;
		//会员不触发答题me->all_fee += fee;//记录玩家的捐赠总数
		if(me->all_fee>=1) entry_flag = 0;
		//10级以下不触发答题和迷宫
		if(me->query_level()<=20) entry_flag = 0;
		
		werror("---player["+me->name+"]----- leave call tmp-wg_times=["+me["/tmp/wg_times"]+"]\n");
		
		if(entry_flag==1){
			int ts_num = 0;//!!!!!!!!!!!!!! 调试数据，正式版设置为0即可
			int add = 0;
			if(random(1000)<1000+ts_num+add){
				if(me["/plus/random_award"]>0){
					//逃跑触发的leave问题不大，因为会先调用停止战斗，再leave
					if(!me->in_combat){
						if(random(100)<100){
							//1.如果触发，则写入存档，下线再上线，调用leave时，也会触发
							me["/plus/random_rcd"] = 1;//触发就置为1，正确完成了，置为0，否则，下线重登录也会触发验证强制界面
							int t1 = random(10) + 1;
							int t2 = random(10) + 1;
							if(random(100)<40) t1 = random(100)+1;
							if(random(100)<10) t2 = random(100)+1;
							int t3 = t1*t2;
							int c1 = random(10) + 1;
							int c2 = random(10) + 1;
							int d1 = random(10) + 1;
							int d2 = random(10) + 1;
							array tmp1 = ({ 
									"§1"+t1+"§r"+c1+d1,
									""+c1+"§1"+t1+"§r"+d1,
									""+c1+""+d1+"§1"+t1+"§r"
									});
							array tmp2 = ({ 
									"§1"+t2+"§r"+c2+d2,
									""+c2+"§1"+t2+"§r"+d2,
									""+c2+""+d2+"§1"+t2+"§r"
									});
							string s1 = tmp1[random(sizeof(tmp1))]; 
							string s2 = tmp2[random(sizeof(tmp2))];
							me["/tmp/rd_tmp1"] = s1;
							me["/tmp/rd_tmp2"] = s2;
							me["/tmp/rd_tmp3"] = t3;
							tell_object(me,"§C请输入两个颜色相同数字相乘的结果§r\n");	
							werror("leave call /tmp/rd_tmp1=["+me["/tmp/rd_tmp1"]+"]\n");
							werror("leave call /tmp/rd_tmp2=["+me["/tmp/rd_tmp2"]+"]\n");
							werror("leave call /tmp/rd_tmp3=["+me["/tmp/rd_tmp3"]+"]\n");
							//////////////////////////////////////////////
							string now=ctime(time());
							string record_s = now[0..sizeof(now)-2]+"|"+me->name+"|"+me->name_cn+"|yanzheng award! left count= ["+me["/plus/random_award"]+"]\n";	
							Stdio.append_file(ROOT+"/log/random_award.log",record_s);
							//////////////////////////////////////////////
							me->reset_view(WAP_VIEWD["/modal_award"]);//该视图负责调出随机抽奖界面，并输入参数供random_award验证
							me->write_view();
							return 1;
						}
					}
				}
			}
		}
	}

	object env=environment(me);
	if(!env || !mappingp(env->exits))
		return 0;
	if(env->exits[arg]&&!env->closed_exits[arg]&&!(env->hidden_exits[arg]&&!present(env->hidden_exits[arg],this_player()))){
		object guarder;
		if(!(env->guarded_exits[arg] &&
		   (guarder=present(env->guarded_exits[arg],env)) &&
		   !this_player()->can_use_room_race(guarder->query_raceId()))){
			string dest=env->exits[arg];
			mapping switch_exits=(env->switch_exits);
			if(switch_exits[arg]){
				foreach(switch_exits[arg],array a){
					int val;
					if(a[0]!=""){
						val=this_player()[a[0]];
						if(val>=a[1]&&val<=a[2]){
							dest=a[3];
							break;
						}
					}
				}
			}
			if(dest!=""){
				if(this_player()->in_combat)
					this_player()->command("attack");
				else{
					this_player()->leave_direction=arg;
					if(this_player()->hind == 0){
						env->addLeaveInfo(this_player());
						env->deleteArriveInfo(this_player()->name);
					}
					if(!this_player()->move(dest))
						return 1;
					// 跨 worker 的静态移动此刻只是事务内逻辑成功；
					// arrive、跟随等房间副作用必须等目标对象落地后再发生。
					if(MAP_WORKERD->query_local_move_redirect(
					   this_player()->query_name())["ok"]){
						detach_worker_move_followers(this_player(),env);
						return 1;
					}
					this_player()->command("arrive");
					//自动跟随在这里添加,liaocheng于07/09/21                
					array(string) tmp_f = this_player()->follow_me;         
					if(sizeof(tmp_f)){
						for(int i=0;i<sizeof(tmp_f);i++){
							if(tmp_f[i] != ""){
								object follower = find_player(tmp_f[i]);
								if(follower){
									if(!LOGICALZONED->can_interact(this_player(),follower)){
										this_player()->follow_me -= ({tmp_f[i]});
										follower->follow = "_none";
										continue;
									}
									if(environment(follower)==env)
										follower->command("leave "+arg);
									else{
										this_player()->follow_me -= ({tmp_f[i]});
										follower->follow = "_none";
									}
								}
								else{
									this_player()->follow_me -= ({tmp_f[i]});
								}
							}
						}
					}
					//自动跟随完毕
				}
			}
			else
				this_player()->write_view(WAP_VIEWD["/leave_noway"]);
		}
		else
			this_player()->write_view(WAP_VIEWD["/leave_guarder"],guarder,0,arg);
	}
	else
		this_player()->write_view(WAP_VIEWD["/leave_noway"]);
	return 1;
}
