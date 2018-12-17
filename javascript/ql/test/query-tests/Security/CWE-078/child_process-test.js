var cp = require("child_process"),
    http = require('http'),
    url = require('url');

var server = http.createServer(function(req, res) {
    let cmd = url.parse(req.url, true).query.path;

    cp.exec("foo"); // OK
    cp.execSync("foo"); // OK
    cp.execFile("foo"); // OK
    cp.execFileSync("foo"); // OK
    cp.spawn("foo"); // OK
    cp.spawnSync("foo"); // OK
    cp.fork("foo"); // OK


    cp.exec(cmd); // NOT OK
    cp.execSync(cmd); // NOT OK
    cp.execFile(cmd); // NOT OK
    cp.execFileSync(cmd); // NOT OK
    cp.spawn(cmd); // NOT OK
    cp.spawnSync(cmd); // NOT OK
    cp.fork(cmd); // NOT OK

    cp.exec("foo" + cmd + "bar"); // NOT OK

    // These are technically NOT OK, but they are more likely as false positives
    cp.exec("foo", {shell: cmd}); // OK
    cp.exec("foo", {env: {PATH: cmd}}); // OK
    cp.exec("foo", {cwd: cmd}); // OK
    cp.exec("foo", {uid: cmd}); // OK
    cp.exec("foo", {gid: cmd}); // OK

    let sh, flag;
    if (process.platform == 'win32')
      sh = 'cmd.exe', flag = '/c';
    else
      sh = '/bin/sh', flag = '-c';
    cp.spawn(sh, [ flag, cmd ]); // NOT OK

    let args = [];
    args[0] = "-c";
    args[1] = cmd;
    cp.execFile("/bin/bash", args); // NOT OK

    run("sh", args);

    let args = [];
    args[0] = `-` + "c";
    args[1] = cmd;
    cp.execFile(`/bin` + "/bash", args); // NOT OK

});

function run(cmd, args) {
  cp.spawn(cmd, args); // NOT OK
}
