#!/usr/bin/env pike
/**
 * 单元测试守护进程
 * 统一运行所有单元测试
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

// 运行测试
void run_tests()
{
	werror("\n========== 运行单元测试 ==========\n");

	// 测试房间编译 - congxianzhenguangchang
	werror("\n[测试] 编译房间 congxianzhenguangchang\n");
	string room_path = ROOT + "/gamelib/d/congxianzhen/congxianzhenguangchang";
	mixed err = catch {
		program p = (program)room_path;
		if (p) {
			werror("  ✓ 编译成功!\n");
			// 尝试创建对象
			object room = p();
			if (room) {
				werror("  ✓ 对象创建成功! name_cn=%s\n", room->name_cn);
			} else {
				werror("  ✗ 对象创建返回 NULL\n");
			}
		} else {
			werror("  ✗ 编译返回 NULL\n");
		}
	};
	if (err) {
		werror("  ✗ 错误: %s\n", describe_error(err));
	}

	// 测试房间编译 - yuhuacunguangchang
	werror("\n[测试] 编译房间 yuhuacunguangchang\n");
	room_path = ROOT + "/gamelib/d/jinaodao/yuhuacunguangchang";
	werror("  文件路径: %s\n", room_path);

	// 先检查文件是否存在
	if(!Stdio.exist(room_path)) {
		werror("  ✗ 文件不存在!\n");
	} else {
		werror("  ✓ 文件存在\n");

		// 读取文件内容
		string content = Stdio.read_file(room_path);
		if(!content) {
			werror("  ✗ 无法读取文件内容!\n");
		} else {
			werror("  ✓ 文件可读，大小: %d 字节\n", sizeof(content));

			// 显示文件前几个字符用于调试
			werror("  文件开头: %s\n", (string)content[..100]);

			// 尝试用 compile_string 编译，这样能看到具体错误
			werror("  尝试用 compile_string 编译...\n");
			mixed compile_result;
			err = catch {
				compile_result = compile_string(content, room_path);
			};
			if(err) {
				werror("  ✗ compile_string 错误: %s\n", describe_error(err));
				werror("  ✗ 回溯:\n%s\n", describe_backtrace(err));
			} else if(compile_result) {
				werror("  ✓ compile_string 成功!\n");
				werror("  ✓ 编译结果类型: %s\n", sprintf("%O", object_program(compile_result)));
			} else {
				werror("  ✗ compile_string 返回 NULL\n");
			}

			// 再尝试用 cast 方式
			werror("  尝试用 (program) cast 方式...\n");
			err = catch {
				program p = (program)room_path;
				if (p) {
					werror("  ✓ cast 成功!\n");
				} else {
					werror("  ✗ cast 返回 NULL\n");
				}
			};
			if (err) {
				werror("  ✗ cast 错误: %s\n", describe_error(err));
			}
		}
	}

	// 运行方士系统测试
	werror("\n========== 运行方士系统测试 ==========\n");
	if(TESTFANGSHID) {
		werror("  调用 TESTFANGSHID->run_tests()...\n");
		TESTFANGSHID->run_tests();
	} else {
		werror("  ! TESTFANGSHID 守护进程未加载\n");
	}

	werror("\n========== 所有测试完成 ==========\n");
}

protected void create()
{
	werror("[TESTUNITD] 单元测试守护进程启动\n");
	call_out(run_tests, 3);
}
