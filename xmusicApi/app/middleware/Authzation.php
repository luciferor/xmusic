<?php
declare (strict_types = 1);

namespace app\middleware;

use think\response\Json;
use think\facade\Cache;
use think\facade\Request;

class Authzation
{
    /**
     * 处理请求
     */
    public function handle($request, \Closure $next)
    {
        //Catch使用Cache::get($user->user);
        //校验请求头参数
        $encryptioncode = Request::header('encrypted-code');
        $timerubbing = Request::header('time-rubbing');
        //请求参数
        $arr = Request::instance()->param('');
        
        if(empty($encryptioncode)&&empty($timerubbing)){//不存在参数直接弹回
            return handleResult(1001,'非法访问',false);
        }else{//存在参数需要校验参数是否正确
            if(checkAuthorHandler($arr,$encryptioncode,$timerubbing)){
                return $next($request);
            }else{
                return handleResult(1001,'非法访问',false);
            }
        }
    }
}
