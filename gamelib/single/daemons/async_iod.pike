#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

// Pike 9 Thread.Farm reuses a bounded set of threads.  Only immutable values
// (paths, strings and integers) may cross this boundary; game objects must
// remain on the single-writer world thread.
#define ASYNC_IO_THREAD_LIMIT 8
#define ASYNC_IO_READ_THREAD_LIMIT 7
#define ASYNC_IO_APPEND_THREAD_LIMIT 1
#define ASYNC_IO_PENDING_LIMIT 2048
#define ASYNC_IO_READ_PENDING_LIMIT 512
#define ASYNC_IO_APPEND_PENDING_LIMIT 1536
#define ASYNC_IO_TEXT_LIMIT (8*1024*1024)

private object read_farm;
private object append_farm;
private Thread.Mutex status_lock = Thread.Mutex();
private int pending_jobs;
private int pending_read_jobs;
private int pending_append_jobs;
private int peak_pending_jobs;
private int completed_jobs;
private int failed_jobs;
private int rejected_jobs;
private int read_jobs;
private int append_jobs;
private int bytes_read;
private int bytes_written;
private int max_job_ms;

protected void create()
{
	// 读取和追加使用独立队列，避免日志洪峰阻塞登录/静态文件读取。
	// 追加池只有一个工作线程，因此同一进程内的日志严格按入队顺序落盘。
	read_farm = Thread.Farm();
	read_farm->set_max_num_threads(ASYNC_IO_READ_THREAD_LIMIT);
	append_farm = Thread.Farm();
	append_farm->set_max_num_threads(ASYNC_IO_APPEND_THREAD_LIMIT);
}

private int safe_path(string path)
{
	string normalized_path;
	string normalized_root;
	string normalized_data_root;
	if(!path || path=="" || search(path,"\0")!=-1 ||
	   search(path,"/../")!=-1 || has_suffix(path,"/.."))
		return 0;
	normalized_path = combine_path("/",path);
	normalized_root = combine_path("/",ROOT);
	normalized_data_root = combine_path("/",DATA_ROOT);
	while(sizeof(normalized_root)>1 && has_suffix(normalized_root,"/"))
		normalized_root = normalized_root[0..sizeof(normalized_root)-2];
	while(sizeof(normalized_data_root)>1 &&
	   has_suffix(normalized_data_root,"/"))
		normalized_data_root =
			normalized_data_root[0..sizeof(normalized_data_root)-2];
	if(has_prefix(normalized_path,normalized_root+"/log/") ||
	   has_prefix(normalized_path,normalized_data_root+"/") ||
	   has_prefix(normalized_path,normalized_root+"/gamelib/u/") ||
	   has_prefix(normalized_path,normalized_root+"/gamelib/data/") ||
	   has_prefix(normalized_path,normalized_root+
		"/gamelib/single/daemons/_http_api_mod/") ||
	   has_prefix(normalized_path,normalized_root+"/web/"))
		return 1;
	return 0;
}

private int reserve_job(string kind)
{
	object key;
	int accepted = 0;
	key = status_lock->lock();
	if(pending_jobs < ASYNC_IO_PENDING_LIMIT &&
	   ((kind=="read" &&
	     pending_read_jobs<ASYNC_IO_READ_PENDING_LIMIT) ||
	    (kind!="read" &&
	     pending_append_jobs<ASYNC_IO_APPEND_PENDING_LIMIT))){
		pending_jobs++;
		if(pending_jobs > peak_pending_jobs)
			peak_pending_jobs = pending_jobs;
		if(kind=="read"){
			pending_read_jobs++;
			read_jobs++;
		}
		else{
			pending_append_jobs++;
			append_jobs++;
		}
		accepted = 1;
	}
	else
		rejected_jobs++;
	destruct(key);
	return accepted;
}

private void finish_job(string kind,int ok,int size,int started_at)
{
	object key;
	int elapsed_ms = (gethrtime()-started_at)/1000;
	key = status_lock->lock();
	if(pending_jobs > 0)
		pending_jobs--;
	if(kind=="read" && pending_read_jobs>0)
		pending_read_jobs--;
	else if(kind!="read" && pending_append_jobs>0)
		pending_append_jobs--;
	if(ok)
		completed_jobs++;
	else
		failed_jobs++;
	if(size >= 0)
		bytes_read += size;
	else
		bytes_written += -size;
	if(elapsed_ms > max_job_ms)
		max_job_ms = elapsed_ms;
	destruct(key);
}

private string|zero read_text_job(string path,int max_bytes)
{
	string|zero source = 0;
	int started_at = gethrtime();
	int ok = 0;
	int missing = 0;
	mixed err = catch {
		int size = Stdio.file_size(path);
		if(size == -1)
			missing = 1;
		else if(size >= 0 && size <= max_bytes)
			// 文件在 file_size 后仍可能增长；限定实际读取长度，避免
			// TOCTOU 让单个请求突破内存边界。
			source = Stdio.read_file(path,0,max_bytes+1);
		if(source && sizeof(source) <= max_bytes)
			ok = 1;
	};
	if(err)
		ok = 0;
	if(missing){
		finish_job("read",1,0,started_at);
		return 0;
	}
	finish_job("read",ok,source ? sizeof(source) : 0,started_at);
	return ok ? source : 0;
}

private void append_text_job(string path,string source)
{
	int started_at = gethrtime();
	int ok = 0;
	mixed err = catch {
		ok = Stdio.append_file(path,source) ? 1 : 0;
	};
	if(err)
		ok = 0;
	finish_job("append",ok,-sizeof(source),started_at);
	if(!ok)
		werror("[ASYNC_IO] append failed: %s\n",path);
}

// Synchronous caller contract with the blocking file operation executed by
// Thread.Farm.  Concurrent.Future::get releases the Pike interpreter while it
// waits, allowing other safe farm jobs to make progress.
string|zero read_text(string path,void|int max_bytes)
{
	object future;
	string|zero source = 0;
	mixed err;
	if(!safe_path(path))
		return 0;
	if(max_bytes <= 0 || max_bytes > ASYNC_IO_TEXT_LIMIT)
		max_bytes = ASYNC_IO_TEXT_LIMIT;
	if(!reserve_job("read"))
		return 0;
	err = catch {
		future = read_farm->run(read_text_job,path,max_bytes);
		source = future->get();
	};
	if(err){
		finish_job("read",0,0,gethrtime());
		return 0;
	}
	return source;
}

private void deliver_read_failure(mixed err,function callback,array extra)
{
	werror("[ASYNC_IO] asynchronous read failed: %s\n",
		describe_error(err));
	callback(0,@extra);
}

// Fully asynchronous read. Concurrent.Future guarantees that callbacks are
// dispatched by the main Backend, so request/game objects in callback extras
// are never touched by a worker thread.
int read_text_async(string path,int max_bytes,function callback,
	mixed ... extra)
{
	object future;
	mixed err;
	if(!callback || !safe_path(path))
		return 0;
	if(max_bytes<=0 || max_bytes>ASYNC_IO_TEXT_LIMIT)
		max_bytes = ASYNC_IO_TEXT_LIMIT;
	if(!reserve_job("read"))
		return 0;
	err = catch {
		future = read_farm->run(read_text_job,path,max_bytes);
		future->on_success(callback,@extra);
		future->on_failure(deliver_read_failure,callback,extra);
	};
	if(err){
		finish_job("read",0,0,gethrtime());
		return 0;
	}
	return 1;
}

// Noncritical audit/performance logs use fire-and-forget I/O.  Queue pressure
// rejects new lines instead of allowing unbounded memory growth.
int append_log(string path,string source)
{
	mixed err;
	if(!safe_path(path) || !has_prefix(path,ROOT+"/log/") ||
	   !source || sizeof(source)>8192)
		return 0;
	if(!reserve_job("append"))
		return 0;
	err = catch {
		append_farm->run_async(append_text_job,path,source);
	};
	if(err){
		finish_job("append",0,0,gethrtime());
		return 0;
	}
	return 1;
}

mapping query_status()
{
	mapping result;
	object key = status_lock->lock();
	result = ([
		"mode":"Thread.Farm",
		"process_model":"single_process",
		"thread_limit":ASYNC_IO_THREAD_LIMIT,
		"read_thread_limit":ASYNC_IO_READ_THREAD_LIMIT,
		"append_thread_limit":ASYNC_IO_APPEND_THREAD_LIMIT,
		"pending_limit":ASYNC_IO_PENDING_LIMIT,
		"read_pending_limit":ASYNC_IO_READ_PENDING_LIMIT,
		"append_pending_limit":ASYNC_IO_APPEND_PENDING_LIMIT,
		"pending_jobs":pending_jobs,
		"pending_read_jobs":pending_read_jobs,
		"pending_append_jobs":pending_append_jobs,
		"peak_pending_jobs":peak_pending_jobs,
		"completed_jobs":completed_jobs,
		"failed_jobs":failed_jobs,
		"rejected_jobs":rejected_jobs,
		"read_jobs":read_jobs,
		"append_jobs":append_jobs,
		"bytes_read":bytes_read,
		"bytes_written":bytes_written,
		"max_job_ms":max_job_ms,
	]);
	destruct(key);
	return result;
}
