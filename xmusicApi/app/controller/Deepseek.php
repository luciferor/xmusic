<?php
namespace app\controller;

use app\BaseController;
use think\facade\Db;
use think\facade\Request;

class Deepseek extends BaseController
{
    public function index()
    {
        var_dump(phpinfo());
    }

    public function chat($name = 'ThinkPHP6')
    {
        $curl = curl_init();

        curl_setopt_array($curl, array(
        CURLOPT_URL => 'https://api.deepseek.com/chat/completions',
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_ENCODING => '',
        CURLOPT_MAXREDIRS => 10,
        CURLOPT_TIMEOUT => 0,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
        CURLOPT_CUSTOMREQUEST => 'POST',
        CURLOPT_POSTFIELDS =>'{
            "messages": [
                {
                "content": "You are a helpful assistant",
                "role": "system"
                },
                {
                "content": "Hi",
                "role": "user"
                }
            ],
            "model": "deepseek-chat",
            "frequency_penalty": 0,
            "max_tokens": 2048,
            "presence_penalty": 0,
            "response_format": {
                "type": "text"
            },
            "stop": null,
            "stream": false,
            "stream_options": null,
            "temperature": 1,
            "top_p": 1,
            "tools": null,
            "tool_choice": "none",
            "logprobs": false,
            "top_logprobs": null
        }',
        CURLOPT_HTTPHEADER => array(
            'Content-Type: application/json',
            'Accept: application/json',
            'Authorization: Bearer sk-4f5e2d4e15274b7ea64620b93bf35723'
        ),
        ));

        $response = curl_exec($curl);

        curl_close($curl);
        echo $response;
        // $info = Request::header();
        return json($response);
    }
    
    function test(){

        // 1. 接收数据（示例接收所有GET参数）
        $data = request()->get();
        
        // 2. 定义日志文件路径（项目根目录下的log.txt）
        $logFile = root_path() . 'esplog.txt';
        
        // 3. 格式化日志内容（时间戳 + 数据）
        $logContent = '[' . date('Y-m-d H:i:s') . '] ' . 
                     json_encode($data, JSON_UNESCAPED_UNICODE) . 
                     PHP_EOL; // 换行符
        
        // 4. 追加写入文件
        file_put_contents($logFile, $logContent, FILE_APPEND);
        
        return json('日志记录成功');
    }
}

class LogUtil
{
    /**
     * 追加数据到日志文件
     * @param mixed $data 要保存的数据（支持字符串/数组/对象）
     * @param string $filename 日志文件名（默认 log.txt）
     */
    public static function append($data, $filename = 'log.txt')
    {
        // 日志目录路径（runtime/log）
        $logDir = runtime_path('log');
        
        // 自动创建目录（如果不存在）
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }

        // 格式化内容：添加时间戳 + 换行
        $content = '[' . date('Y-m-d H:i:s') . '] ' . 
                  (is_scalar($data) ? $data : json_encode($data, JSON_UNESCAPED_UNICODE)) . 
                   PHP_EOL;

        // 追加写入文件
        file_put_contents($logDir . '/' . $filename, $content, FILE_APPEND);
    }
}
