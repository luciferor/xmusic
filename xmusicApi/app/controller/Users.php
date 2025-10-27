<?php
namespace app\controller;

use app\BaseController;
use think\facade\Db;
use think\facade\Request;

class Users extends BaseController
{
    public function index()
    {
        var_dump(Db::table('sys_users')->select());
        return '<h1>Hello!</h1>';
    }

    //新增用户 | 获取验证码
    public function userCheckcodeRegister()
    {
        $arr = Request::instance()->param('');
        if (!empty($arr['email'])) {
            $code = RandomNumberCode(6);
            return handleResult(200, sendEmail('注册验证码', $code, $arr['email']), true);
        } else {
            return handleResult(500, '邮箱地址不能为空~', false);
        }
    }

    //新增用户 | 注册
    public function userRegister()
    {
        $arr = Request::instance()->param('');
        if (!empty($arr['phone']) && !empty($arr['code']) && !empty($arr['password']) && !empty($arr['repassword'])) {
            $users = Db::table('sys_member_users')->where('phone', $arr['phone'])->find();
            if (!empty($users) && $arr['phone'] == $users['phone']) {
                return handleResult(500, '手机号已被注册，请更换手机号后重试~', false);
            }
            $data = array(
                'avator' => $arr['avator'],
                'uuid' => $arr['uuid'],
                'phone' => $arr['phone'],
                'password' => password_hash($arr['password'], PASSWORD_DEFAULT),
                'status' => 1,
                'isdel' => 0,
                'grade' => 1,
                'open_id' => md5($arr['phone']),
                'devicesinfo' => $arr['device'],
                'platform' => $arr['platform'],
                'created_at' => strtotime(date("Y-m-d H:i:s")),
                'updated_at' => strtotime(date("Y-m-d H:i:s")),
            );
            if (Db::table("sys_member_users")->insert($data)) {
                return handleResult(200, '注册成功，去登录~', true);
            } else {
                return handleResult(500, '注册失败~', false);
            }
        } else {
            return handleResult(500, '参数错误~', false);
        }
    }

    //用户登录
    public function userLogin()
    {
        $arr = Request::instance()->param('');
        if (!empty($arr['phone']) && !empty($arr['password'])) {
            $userinfo = Db::table('sys_member_users')->field(['password'])->where('phone', $arr['phone'])->find();
            if ($userinfo) {
                if (password_verify($arr['password'], $userinfo['password'])) {
                    Db::table('sys_member_users')->where('phone', $arr['phone'])->update(['loginendtime' => strtotime(date("Y-m-d H:i:s"))]);
                    return handleResult(200, signToken(Db::table('sys_member_users')->where('phone', $arr['phone'])->field(['id', 'open_id', 'uuid', 'phone', 'email', 'nickname', 'avator', 'gender', 'grade', 'name', 'cardno', 'province', 'city', 'county', 'address', 'interest', 'status', 'isdel', 'motto', 'created_at', 'updated_at'])->find()), true);
                } else {
                    return handleResult(500, '密码错误~', false);
                }
            } else {
                return handleResult(500, '账户不存在，请先注册~', false);
            }
        } else {
            return handleResult(500, '参数错误~', false);
        }
    }

    //获取用户信息
    public function getUserinfos()
    {
        $token = Request::header('authorization') ?? false;
        if ($token) {
            return handleResult(200, extendTokenInfo(), true);
        } else {
            return handleResult(201, 'token过期,或不存在~', false);
        }

    }

    //更新用户信息
    public function updateUserinfos()
    {
        $arr = Request::instance()->param('');
        if (!empty($arr['avator']) && !empty('nickname')) {
            $data = [
                'email' => $arr['email'],
                'nickname' => $arr['nickname'],
                'avator' => $arr['avator'],
                'gender' => $arr['gender'],
                'grade' => $arr['grade'],
                'name' => $arr['name'],
                'cardno' => $arr['cardno'],
                'province' => $arr['province'],
                'city' => $arr['city'],
                'county' => $arr['county'],
                'address' => $arr['address'],
                'interest' => $arr['interest'],
                'motto' => $arr['motto'],
                'updated_at' => strtotime(date("Y-m-d H:i:s")),
            ];
            if (Db::table('sys_member_users')->where('id', $arr['id'])->update($data)) {
                //更新成功重新生成token传回客户端。
                return handleResult(200, signToken(Db::table('sys_member_users')->where('id', $arr['id'])->field(['id', 'open_id', 'uuid', 'phone', 'email', 'nickname', 'avator', 'gender', 'grade', 'name', 'cardno', 'province', 'city', 'county', 'address', 'interest', 'status', 'isdel', 'motto', 'created_at', 'updated_at'])->find()), true);
            } else {
                return handleResult(500, '更新用户信息失败', false);
            }
        } else {
            return handleResult(500, '参数错误~', false);
        }
    }

    //获取用户排行
    public function getRanking()
    {
        $arr = Request::instance()->param('');
        if (!empty($arr['count'])) {
            $data = Db::table('sys_member_users')
                ->alias('u')
                ->join('sys_todo_done t', 't.user_id=u.id', 'LEFT')
                ->join('sys_zans z', 'z.user_id = u.id', 'LEFT')
                ->field('u.id,u.uuid,u.nickname,u.avator,u.motto,SUM(t.minutes) AS u_minutes,SUM(z.zan) as zans')
                ->order('u_minutes desc')
                ->order('u.created_at asc')
                ->group('u.id')
                ->paginate($arr['count']);
            return handleResult(200, $data, true);
        } else {
            $data = Db::table('sys_member_users')
                ->alias('u')
                ->join('sys_todo_done t', 't.user_id=u.id', 'LEFT')
                ->field('u.id,u.uuid,u.nickname,u.avator,u.motto,SUM(t.minutes) AS u_minutes,SUM(z.zan) as zans')
                ->order('u_minutes desc')
                ->order('u.created_at asc')
                ->group('u.id')
                ->paginate();
            return handleResult(200, $data, true);
        }

    }
}
