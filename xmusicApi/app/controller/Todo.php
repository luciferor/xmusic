<?php
namespace app\controller;

use app\BaseController;
use think\facade\Db;
use think\facade\Request;

class Todo extends BaseController
{
    public function index()
    {
    }

    //获取专注列表
    public function getTodoList()
    {
        $token = Request::header('authorization') ?? false;
        if ($token) {
            $params = Request::instance()->param('');
            $userid = extendTokenInfo()['id'];
            return handleResult(200, Db::table('sys_todos')->alias('t')
                ->join('sys_todo_done d', 'todo_id = t.id', 'LEFT')
                ->where('t.userid', $userid)
                ->whereBetweenTimeField('t.start_time', 't.end_time')
                // ->whereTime('t.start_time', '<=', date("Y-m-d H:i:s", strtotime($params['date'])))
                // ->whereTime('t.end_time', '>=', date("Y-m-d H:i:s", strtotime($params['date'])))
                ->field('t.id,t.icon,t.title,t.progress,t.minutes,t.userid,t.start_time,t.end_time,t.isforce,t.sort')
                ->order('t.sort asc')
                ->order('t.updated_at desc')
                ->select(), true);
        } else {
            return handleResult(201, 'token过期,或不存在~', false);
        }
    }

    //获取专注详情
    public function getTodoDetail()
    {
        $params = Request::instance()->param('');
        if (!empty($params['id'])) {
            return handleResult(200, Db::table('sys_todos')->where('id', $params['id'])->find(), true);
        } else {
            return handleResult(500, '参数错误～', false);
        }
    }

    //添加专注事项
    public function addTodo()
    {
        $userid = extendTokenInfo()['id'];
        $params = Request::instance()->param('');
        if (!empty($params['title']) && !empty($params['icon']) && !empty($params['start']) && !empty($params['end']) && !empty($params['minutes'])) {
            $data = [
                'userid' => $userid,
                'icon' => $params['icon'],
                'title' => $params['title'],
                'start_time' => $params['start'],
                'end_time' => $params['end'],
                'minutes' => $params['minutes'],
                'progress' => 0,
                'sort' => 0,
                'isforce' => $params['isforce'],
                'created_at' => strtotime(date("Y-m-d H:i:s")),
                'updated_at' => strtotime(date("Y-m-d H:i:s")),
            ];
            if (Db::table('sys_todos')->insert($data)) {
                return handleResult(200, '添加成功了～', true);
            } else {
                return handleResult(500, '添加失败了～', false);
            }
        } else {
            return handleResult(500, '参数错误～', false);
        }
    }

    //排序
    public function sorttodo()
    {
        $params = Request::instance()->param('');
        foreach ($params['sort'] as $key => $value) {
            Db::table('sys_todos')->where('id', $value['id'])->update(['sort' => $value['sort'], 'updated_at' => strtotime(date("Y-m-d H:i:s"))]);
        }
        return handleResult(200, 'yes', true);
    }

    //修改专注事项
    public function updateTodo()
    {
        $params = Request::instance()->param('');
    }

    //完成专注实现
    public function doneTodo()
    {
        $params = Request::instance()->param('');
        $userid = extendTokenInfo()['id'];
        if (!empty($params['todo_id']) && !empty($params['minutes']) && !empty($params['date'])) {
            $data = [
                'user_id' => $userid,
                'todo_id' => $params['todo_id'],
                'minutes' => $params['minutes'],
                'date' => $params['date'],
                'created_at' => strtotime(date("Y-m-d H:i:s")),
                'updated_at' => strtotime(date("Y-m-d H:i:s")),
            ];
            if (Db::table('sys_todo_done')->insert($data)) {
                //更新专注表为完成
                Db::table('sys_todos')->where('id', $params['todo_id'])->update(['progress' => $params['minutes']]);
                //加点积分
                Db::table('sys_member_integral')->insert([
                    'user_id' => $userid,
                    'integral' => 20,
                    'type' => 1,
                    'created_at' => strtotime(date("Y-m-d H:i:s")),
                    'updated_at' => strtotime(date("Y-m-d H:i:s")),
                ]);
                return handleResult(200, '恭喜您，完成了～', true);
            } else {
                return handleResult(500, '记录失败了～', false);
            }
        } else {
            return handleResult(500, '参数错误～', false);
        }
    }
}
