# 動態規劃（Dynamic Programming）

```
動態規劃解題框架：
  ① 定義狀態（dp[i] 代表什麼？）
  ② 找狀態轉移方程（dp[i] 怎麼從前面的狀態得到？）
  ③ 確定初始值（dp[0] / dp[1] 是多少？）
  ④ 確定遍歷順序（從小到大還是從大到小？）
```

## 基礎 DP

```java
// ════════════════════════════════
// 題目 1：爬樓梯（Fibonacci 變形）
// 每次可以爬 1 或 2 階，到達 n 階有幾種方法？
// ════════════════════════════════
public int climbStairs(int n) {
    if (n <= 2) return n;

    // dp[i] = 到達第 i 階的方法數
    int[] dp = new int[n + 1];
    dp[1] = 1;
    dp[2] = 2;

    for (int i = 3; i <= n; i++) {
        dp[i] = dp[i - 1] + dp[i - 2]; // 從 i-1 爬 1 步 或從 i-2 爬 2 步
    }
    return dp[n];
}
// 時間：O(n)，空間：O(n)

// 空間優化（只需要前兩個值）
public int climbStairsOptimized(int n) {
    if (n <= 2) return n;
    int prev2 = 1, prev1 = 2;
    for (int i = 3; i <= n; i++) {
        int curr = prev1 + prev2;
        prev2 = prev1;
        prev1 = curr;
    }
    return prev1;
}
// 時間：O(n)，空間：O(1)

// ════════════════════════════════
// 題目 2：打家劫舍（不能搶相鄰的房子）
// 輸入：[2,7,9,3,1]
// 輸出：12（2+9+1）
// ════════════════════════════════
public int rob(int[] nums) {
    if (nums.length == 1) return nums[0];

    // dp[i] = 搶前 i 個房子能獲得的最大金額
    int[] dp = new int[nums.length];
    dp[0] = nums[0];
    dp[1] = Math.max(nums[0], nums[1]);

    for (int i = 2; i < nums.length; i++) {
        // 搶第 i 個：dp[i-2] + nums[i]
        // 不搶第 i 個：dp[i-1]
        dp[i] = Math.max(dp[i - 1], dp[i - 2] + nums[i]);
    }
    return dp[nums.length - 1];
}
```

## 背包問題

```java
// ════════════════════════════════
// 0/1 背包問題
// n 個物品，每個有重量 weight[i] 和價值 value[i]
// 背包容量為 W，求能裝的最大價值
// ════════════════════════════════
public int knapsack(int W, int[] weight, int[] value) {
    int n = weight.length;
    // dp[i][j] = 前 i 個物品，背包容量為 j 時的最大價值
    int[][] dp = new int[n + 1][W + 1];

    for (int i = 1; i <= n; i++) {
        for (int j = 0; j <= W; j++) {
            // 裝不下第 i 個物品
            if (j < weight[i - 1]) {
                dp[i][j] = dp[i - 1][j];
            } else {
                // 不裝 vs 裝
                dp[i][j] = Math.max(
                    dp[i - 1][j],
                    dp[i - 1][j - weight[i - 1]] + value[i - 1]
                );
            }
        }
    }
    return dp[n][W];
}
// 時間：O(n×W)，空間：O(n×W)

// ════════════════════════════════
// 題目：分割等和子集（背包的應用）
// 輸入：[1,5,11,5]
// 輸出：true（[1,5,5] 和 [11] 等和）
// ════════════════════════════════
public boolean canPartition(int[] nums) {
    int sum = Arrays.stream(nums).sum();
    if (sum % 2 != 0) return false; // 和為奇數，不可能分割

    int target = sum / 2;
    // dp[j] = 是否能從數組中選出若干數，使其和恰好為 j
    boolean[] dp = new boolean[target + 1];
    dp[0] = true; // 選 0 個數，和為 0

    for (int num : nums) {
        // ⚠️ 從大到小遍歷（0/1 背包，每個物品只用一次）
        for (int j = target; j >= num; j--) {
            dp[j] = dp[j] || dp[j - num];
        }
    }
    return dp[target];
}
```

## 最長子序列

```java
// ════════════════════════════════
// 題目 1：最長遞增子序列（LIS）
// 輸入：[10,9,2,5,3,7,101,18]
// 輸出：4（[2,3,7,101]）
// ════════════════════════════════
public int lengthOfLIS(int[] nums) {
    int n = nums.length;
    // dp[i] = 以 nums[i] 結尾的最長遞增子序列長度
    int[] dp = new int[n];
    Arrays.fill(dp, 1); // 每個元素本身就是長度 1 的子序列

    int maxLen = 1;
    for (int i = 1; i < n; i++) {
        for (int j = 0; j < i; j++) {
            if (nums[j] < nums[i]) { // nums[i] 可以接在 nums[j] 後面
                dp[i] = Math.max(dp[i], dp[j] + 1);
            }
        }
        maxLen = Math.max(maxLen, dp[i]);
    }
    return maxLen;
}
// 時間：O(n²)，空間：O(n)

// ════════════════════════════════
// 題目 2：最長公共子序列（LCS）
// 輸入："abcde" 和 "ace"
// 輸出：3（"ace"）
// ════════════════════════════════
public int longestCommonSubsequence(String text1, String text2) {
    int m = text1.length(), n = text2.length();
    // dp[i][j] = text1 前 i 個字符 和 text2 前 j 個字符的最長公共子序列
    int[][] dp = new int[m + 1][n + 1];

    for (int i = 1; i <= m; i++) {
        for (int j = 1; j <= n; j++) {
            if (text1.charAt(i - 1) == text2.charAt(j - 1)) {
                // 末尾字符相同 → 公共子序列長度 + 1
                dp[i][j] = dp[i - 1][j - 1] + 1;
            } else {
                // 末尾字符不同 → 取捨一個末尾字符的最大值
                dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]);
            }
        }
    }
    return dp[m][n];
}
// 時間：O(m×n)，空間：O(m×n)

// ════════════════════════════════
// 題目 3：最小編輯距離
// 輸入："horse" → "ros"
// 輸出：3（替換 h→r, 刪除 r, 刪除 e）
// ════════════════════════════════
public int minDistance(String word1, String word2) {
    int m = word1.length(), n = word2.length();
    // dp[i][j] = word1 前 i 個字符 轉換為 word2 前 j 個字符的最少操作數
    int[][] dp = new int[m + 1][n + 1];

    // 初始化：空字串轉換需要 i 或 j 次操作
    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;

    for (int i = 1; i <= m; i++) {
        for (int j = 1; j <= n; j++) {
            if (word1.charAt(i - 1) == word2.charAt(j - 1)) {
                dp[i][j] = dp[i - 1][j - 1]; // 字符相同，不需要操作
            } else {
                dp[i][j] = Math.min(
                    dp[i - 1][j] + 1,     // 刪除 word1[i]
                    Math.min(
                        dp[i][j - 1] + 1, // 插入 word2[j]
                        dp[i - 1][j - 1] + 1 // 替換
                    )
                );
            }
        }
    }
    return dp[m][n];
}
```
