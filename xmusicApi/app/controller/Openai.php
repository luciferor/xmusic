<?php
namespace app\controller;

use app\BaseController;
use think\facade\Db;
use think\facade\Request;

class Openai extends BaseController
{
    public function index()
    {
        var_dump(Db::table('sys_users')->select());
        return '<h1>Hello!</h1>';
    }

    //chatgpt openai接口
    public function openaiSingle()
    {
        $params = Request::instance()->param('');
        if (!empty($params['keywords']) && !empty($params['old']) && !empty($params['system'])) {
            $data = json_encode([
                "model" => "gpt-3.5-turbo-1106",
                "messages" => [
                    [
                        "role" => "system",
                        "content" => $params['system']
                    ],
                    [
                        "role" => "assistant",
                        "content" => $params['old']
                    ],
                    [
                        "role" => "user",
                        "content" => $params['keywords']
                    ],
                ]
            ]);
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
            curl_setopt($ch, CURLOPT_URL, 'https://api.nextapi.fun/openai/v1/chat/completions');
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
            curl_setopt($ch, CURLOPT_POST, 1);
            curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
            curl_setopt(
                $ch,
                CURLOPT_HTTPHEADER,
                array(
                    "Content-Type: application/json",
                    "Authorization: Bearer ak-iIsV1EdPlBLXBU6KRqCaZVg9SK9nVWZE6Z9L8rh6r3IdGxPG"
                )
            );
            $response = curl_exec($ch);
            curl_close($ch);
            return handleResult(200, json_decode($response), true);
        } else {
            return handleResult(500, '参数错误', false);
        }
    }

    //获取对话列表
    public function getSession()
    {
        $arr = Request::instance()->param('');
        $userid = extendTokenInfo()['id'];
        if (!empty($userid)) {
            return handleResult(200, Db::table('sys_openaisession')->where('user_id', $userid)->where('agent_id', $arr['agentid'])->order('id desc')->find(), true);
        } else {
            return handleResult(500, '参数错误', false);
        }
    }

    //新增或更新会话
    public function newSession()
    {
        $arr = Request::instance()->param('');
        $userid = extendTokenInfo()['id'];
        if (!empty($userid) && !empty($arr['usession']) && !empty($arr['title']) && !empty($arr['agentid'])) {
            if (!empty($arr['id'])) { //更新
                $data = [
                    "agent_id" => $arr['agentid'],
                    "session_title" => $arr['title'],
                    "user_session" => $arr['usession'],
                    "update_at" => strtotime(date("Y-m-d H:i:s")),
                ];
                if (Db::table('sys_openaisession')->where('id', $arr['id'])->where('user_id', $userid)->update($data)) {
                    return handleResult(200, '更新会话成功', true);
                } else {
                    return handleResult(500, '更新会话失败', false);
                }
            } else {
                $data = [
                    "user_id" => $userid,
                    "agent_id" => $arr['agentid'],
                    "session_title" => $arr['title'],
                    "user_session" => $arr['usession'],
                    "created_at" => strtotime(date("Y-m-d H:i:s")),
                    "update_at" => strtotime(date("Y-m-d H:i:s")),
                ];
                if (Db::table('sys_openaisession')->insert($data)) {
                    return handleResult(200, '添加会话成功~', true);
                } else {
                    return handleResult(500, '添加会话失败~', false);
                }
            }
        } else {
            return handleResult(500, '参数错误~', false);
        }
    }

    //新增智能体
    public function newIntelligenAgent()
    {
        $arr = Request::instance()->param('');
        $userid = extendTokenInfo()['id'];
        if (!empty($userid) && !empty($arr['avator']) && !empty($arr['name']) && !empty($arr['system'])) {
            if (!empty($arr['id'])) { //更新
                $data = [
                    "avator" => $arr['avator'],
                    "name" => $arr['name'],
                    "system" => $arr['system'],
                    "isshare" => $arr['isshare'],
                    "updated_at" => strtotime(date("Y-m-d H:i:s")),
                ];
                if (Db::table('sys_aiagent')->where('id', $arr['id'])->where('user_id', $userid)->update($data)) {
                    return handleResult(200, '更新会话成功~', true);
                } else {
                    return handleResult(500, '更新会话失败~', false);
                }
            } else {
                $data = [
                    "user_id" => $userid,
                    "avator" => $arr['avator'],
                    "name" => $arr['name'],
                    "system" => $arr['system'],
                    "isshare" => $arr['isshare'],
                    "created_at" => strtotime(date("Y-m-d H:i:s")),
                    "updated_at" => strtotime(date("Y-m-d H:i:s")),
                ];
                if (Db::table('sys_aiagent')->insert($data)) {
                    return handleResult(200, '添加智能体成功~', true);
                } else {
                    return handleResult(500, '添加智能体失败~', false);
                }
            }
        } else {
            return handleResult(500, '参数错误~', false);
        }
    }

    //获取智能体列表
    public function getIntelligenAgent()
    {
        $userid = extendTokenInfo()['id'];
        if (!empty($userid)) {
            $data = Db::table('sys_aiagent')
            ->alias('a')
            ->join('sys_agentops t','a.id = t.agent_id','LEFT')
            ->where('a.user_id', $userid)
            ->whereOr('a.isshare', 1)
            ->field('a.avator,a.name,a.system,a.user_id,a.isshare,a.id,t.istop')
            ->order('t.istop desc')
            ->order('a.updated_at desc')
            ->select();
            return handleResult(200, $data, true);
        } else {
            return handleResult(500, '参数错误~', false);
        }
    }

    //置顶
    public function istop()
    {
        $userid = extendTokenInfo()['id'];
        $arr = Request::instance()->param('');
        if (!empty($arr['id'])) {
            $agent = Db::table('sys_agentops')->where('agent_id', $arr['id'])->where('user_id',$userid)->find();
            if($agent){
                $data = [
                    'istop' => $agent['istop'] == 1 ? 0 : 1,
                    "updated_at" => strtotime(date("Y-m-d H:i:s")),
                ];
                if (Db::table('sys_agentops')->where('agent_id', $arr['id'])->where('user_id',$userid)->update($data)) {
                    return handleResult(200, $agent['istop'] == 1 ? '取消置顶成功~' : '置顶成功~', true);
                } else {
                    return handleResult(500, '置顶失败~', false);
                }
            }else{
                $data = [
                    "user_id" => $userid,
                    "agent_id" => $arr['id'],
                    "istop" => 1,
                    "created_at" => strtotime(date("Y-m-d H:i:s")),
                    "updated_at" => strtotime(date("Y-m-d H:i:s")),
                ];
                if(Db::table('sys_agentops')->insert($data)){
                    return handleResult(200, '置顶成功~', true);
                }else{
                    return handleResult(500, '置顶失败~', false);
                }
            }
        } else {
            return handleResult(500, '参数错误~', false);
        }
    }

    //删除智能体
    public function deleteagent()
    {
        $arr = Request::instance()->param('');
        if (!empty($arr['id'])) {
            if (Db::table('sys_aiagent')->where('id', $arr['id'])->delete()) {
                //删除会话记录
                Db::table('sys_openaisession')->where('agent_id', $arr['id'])->delete();
                return handleResult(200, '删除成功~', true);
            } else {
                return handleResult(500, '删除失败~', false);
            }
        } else {
            return handleResult(500, '参数错误~', false);
        }
    }

    //清除会话记录
    public function clearChat()
    {
        $arr = Request::instance()->param('');
        if (!empty($arr['id'])) {
            if (Db::table('sys_openaisession')->where('agent_id', $arr['id'])->delete()) {
                return handleResult(200, '清除成功~', true);
            } else {
                return handleResult(500, '删除失败~', false);
            }
        } else {
            return handleResult(500, '参数错误~', false);
        }
    }

}
