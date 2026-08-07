#!/usr/bin/env pike
/**
 * Vue 镜像构建链静态契约测试。
 *
 * 覆盖：
 * - rebuild-image.sh 在 Docker 前调用统一前端构建脚本
 * - BUILD_FRONTEND_ONLY 验证入口
 * - app/realm CSS、JS、manifest 与历史 dist 同步
 * - Dockerfile 将 web 产物复制到 Tomcat ROOT
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,
	"passed":0,
	"failed":0,
]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[Vue构建链 %d] %s\n",test_results["total"],name);
}

void test_pass()
{
	test_results["passed"]++;
	werror("  ✓ 通过\n");
}

void test_fail(string reason)
{
	test_results["failed"]++;
	werror("  ✗ 失败: %s\n",reason);
}

void test_rebuild_entry_contract()
{
	test_start("镜像构建前强制执行统一前端构建");
	string source = Stdio.read_file(ROOT+"/rebuild-image.sh");
	int frontend_call = -1;
	int image_call = -1;

	if(source){
		frontend_call = search(source,
			"    build_vue_frontend\n");
		image_call = search(source,"    build_image\n");
	}
	if(source &&
	   search(source,
		"scripts/build/build_vue_frontend.sh")!=-1 &&
	   search(source,"BUILD_FRONTEND_ONLY")!=-1 &&
	   frontend_call!=-1 && image_call!=-1 &&
	   frontend_call<image_call)
		test_pass();
	else
		test_fail("前端构建入口、仅前端模式或调用顺序错误");
}

void test_shared_build_script_contract()
{
	test_start("统一脚本执行测试、构建和产物一致性校验");
	string source = Stdio.read_file(
		ROOT+"/scripts/build/build_vue_frontend.sh");

	if(source &&
	   search(source,"npm test")!=-1 &&
	   search(source,"npm run build")!=-1 &&
	   search(source,"css/realm.css")!=-1 &&
	   search(source,"vendor/vue.global.prod.js")!=-1 &&
	   search(source,"cmp -s")!=-1 &&
	   search(source,"Dockerfile.all")!=-1)
		test_pass();
	else
		test_fail("统一前端构建脚本缺少测试、构建或校验步骤");
}

void test_vue_source_contract()
{
	test_start("Vue源码完整进入正式和历史产物目录");
	string build_source =
		Stdio.read_file(ROOT+"/vue_source/build.js");
	string index_source =
		Stdio.read_file(ROOT+"/vue_source/index.html");

	if(build_source && index_source &&
	   search(build_source,"css', 'app.css")!=-1 &&
	   search(build_source,"css', 'realm.css")!=-1 &&
	   search(build_source,"js', 'app.js")!=-1 &&
	   search(build_source,"'vue.global.prod.js'")!=-1 &&
	   search(build_source,"'VUE_LICENSE.txt'")!=-1 &&
	   search(build_source,"legacyDistDir")!=-1 &&
	   search(index_source,"manifest.json")!=-1 &&
	   search(index_source,"css/realm.css?v=BUILD_VERSION")!=-1 &&
	   search(index_source,
		"vendor/vue.global.prod.js?v=BUILD_VERSION")!=-1 &&
	   search(index_source,"unpkg.com/vue")==-1)
		test_pass();
	else
		test_fail("Vue源码复制或入口引用契约不完整");
}

void test_manifest_contract()
{
	test_start("PWA路径保持相对且引用实际favicon");
	string source =
		Stdio.read_file(ROOT+"/vue_source/manifest.js");

	if(source &&
	   search(source,"id: './'")!=-1 &&
	   search(source,"start_url: './'")!=-1 &&
	   search(source,"scope: './'")!=-1 &&
	   search(source,"src: 'favicon.ico'")!=-1)
		test_pass();
	else
		test_fail("manifest相对路径或favicon配置错误");
}

void test_auto_browser_login_contract()
{
	test_start("自动浏览器登录与HTML直达链接保持兼容");
	string index_source =
		Stdio.read_file(ROOT+"/vue_source/index.html");
	string app_source =
		Stdio.read_file(ROOT+"/vue_source/js/app.js");

	if(index_source && app_source &&
	   search(index_source,"<div class=\"auth-form\">")!=-1 &&
	   search(index_source,"@click=\"doLogin\"")!=-1 &&
	   search(index_source,"@keyup.enter=\"doLogin\"")!=-1 &&
	   search(index_source,"type=\"button\"")!=-1 &&
	   search(index_source,"name=\"username\"")==-1 &&
	   search(index_source,"name=\"password\"")==-1 &&
	   search(index_source,"<form class=\"auth-form\"")==-1 &&
	   search(index_source,
		"@click=\"handleMudButtonClick($event, segment.cmd)\"")!=-1 &&
	   search(index_source,
		"@click.prevent=\"!htmlMode")==-1 &&
	   search(app_source,
		"handleMudButtonClick(event, cmd)")!=-1 &&
	   search(app_source,"if (this.htmlMode)")!=-1 &&
	   search(app_source,"event.preventDefault();")!=-1)
		test_pass();
	else
		test_fail("登录按钮或HTML模式链接会阻止自动浏览器操作");
}

void test_docker_copy_contract()
{
	test_start("Docker镜像复制web产物到Tomcat ROOT");
	string source =
		Stdio.read_file(ROOT+"/docker/Dockerfile.all");

	if(source &&
	   search(source,
		"COPY web /usr/local/tomcat/webapps/ROOT")!=-1)
		test_pass();
	else
		test_fail("Dockerfile未复制正式前端目录");
}

void print_summary()
{
	werror("\n========================================\n");
	werror("Vue构建链测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],
		test_results["passed"],
		test_results["failed"]);
	werror("========================================\n");
}

int main()
{
	test_rebuild_entry_contract();
	test_shared_build_script_contract();
	test_vue_source_contract();
	test_manifest_contract();
	test_auto_browser_login_contract();
	test_docker_copy_contract();
	print_summary();
	if(test_results["failed"]==0)
		return 0;
	return 1;
}
