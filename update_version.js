const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'AppScope/app.json5'); // 注意路径
const appConfig = JSON.parse(fs.readFileSync(filePath, 'utf8'));

let currentCode = appConfig.app.versionCode;

// 提取流水号 pp (最后两位)
let pp = currentCode % 100;
let base = Math.floor(currentCode / 100);

if (pp < 99) {
    pp++;
    const newCode = base * 100 + pp;
    appConfig.app.versionCode = newCode;

    // 写入文件 (保持 JSON 格式)
    fs.writeFileSync(filePath, JSON.stringify(appConfig, null, 2), 'utf8');
    console.log(`✅ VersionCode updated: ${currentCode} -> ${newCode}`);
} else {
    console.error('❌ Error: pp has reached 99. Please bump x, y, or z manually.');
    process.exit(1); // 终止提交
}