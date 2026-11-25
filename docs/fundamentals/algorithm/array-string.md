# 陣列 / 字串

## 雙指針（Two Pointers）

```
核心思想：
  用兩個指針（左右 or 快慢）
  在一次遍歷中完成需要兩次遍歷才能完成的事
  時間複雜度從 O(n²) 降到 O(n)
```

```java
// ════════════════════════════════
// 題目 1：兩數之和（已排序陣列）
// 輸入：nums = [2, 7, 11, 15], target = 9
// 輸出：[0, 1]（nums[0] + nums[1] = 9）
// ════════════════════════════════
public int[] twoSum(int[] nums, int target) {
    int left = 0, right = nums.length - 1;

    while (left < right) {
        int sum = nums[left] + nums[right];

        if (sum == target) {
            return new int[]{left, right};
        } else if (sum < target) {
            left++;   // 和太小，左指針右移（增大和）
        } else {
            right--;  // 和太大，右指針左移（減小和）
        }
    }
    return new int[]{-1, -1};
}
// 時間：O(n)，空間：O(1)

// ════════════════════════════════
// 題目 2：反轉字串
// 輸入：["h","e","l","l","o"]
// 輸出：["o","l","l","e","h"]
// ════════════════════════════════
public void reverseString(char[] s) {
    int left = 0, right = s.length - 1;

    while (left < right) {
        char temp   = s[left];
        s[left]     = s[right];
        s[right]    = temp;
        left++;
        right--;
    }
}
// 時間：O(n)，空間：O(1)

// ════════════════════════════════
// 題目 3：三數之和（找所有不重複的三元組使和為 0）
// 輸入：nums = [-1, 0, 1, 2, -1, -4]
// 輸出：[[-1,-1,2],[-1,0,1]]
// ════════════════════════════════
public List<List<Integer>> threeSum(int[] nums) {
    List<List<Integer>> result = new ArrayList<>();
    Arrays.sort(nums); // 先排序！

    for (int i = 0; i < nums.length - 2; i++) {
        // 跳過重複的 i（去重）
        if (i > 0 && nums[i] == nums[i - 1]) continue;
        // 最小值已經大於 0，後面不可能有解
        if (nums[i] > 0) break;

        int left  = i + 1;
        int right = nums.length - 1;

        while (left < right) {
            int sum = nums[i] + nums[left] + nums[right];

            if (sum == 0) {
                result.add(Arrays.asList(nums[i], nums[left], nums[right]));
                // 跳過重複的 left 和 right
                while (left < right && nums[left]  == nums[left + 1])  left++;
                while (left < right && nums[right] == nums[right - 1]) right--;
                left++;
                right--;
            } else if (sum < 0) {
                left++;
            } else {
                right--;
            }
        }
    }
    return result;
}
// 時間：O(n²)，空間：O(1)
```

## 滑動視窗（Sliding Window）

```
核心思想：
  維護一個可變長度的視窗（子陣列 / 子字串）
  右邊界向右擴展（加入新元素）
  當視窗不滿足條件時，左邊界向右收縮
  整體時間複雜度 O(n)
```

```java
// ════════════════════════════════
// 題目 1：無重複字元的最長子字串
// 輸入："abcabcbb"
// 輸出：3（"abc"）
// ════════════════════════════════
public int lengthOfLongestSubstring(String s) {
    Map<Character, Integer> window = new HashMap<>();
    int left = 0, maxLen = 0;

    for (int right = 0; right < s.length(); right++) {
        char c = s.charAt(right);
        window.put(c, window.getOrDefault(c, 0) + 1);

        // 視窗中有重複字元 → 收縮左邊界
        while (window.get(c) > 1) {
            char leftChar = s.charAt(left);
            window.put(leftChar, window.get(leftChar) - 1);
            left++;
        }

        maxLen = Math.max(maxLen, right - left + 1);
    }
    return maxLen;
}
// 時間：O(n)，空間：O(k)（k = 字符集大小）

// ════════════════════════════════
// 題目 2：長度最小的子陣列（和 ≥ target）
// 輸入：target = 7, nums = [2,3,1,2,4,3]
// 輸出：2（[4,3] 的長度）
// ════════════════════════════════
public int minSubArrayLen(int target, int[] nums) {
    int left = 0, sum = 0;
    int minLen = Integer.MAX_VALUE;

    for (int right = 0; right < nums.length; right++) {
        sum += nums[right]; // 右邊界擴展

        // 滿足條件 → 嘗試收縮左邊界（找更短的）
        while (sum >= target) {
            minLen = Math.min(minLen, right - left + 1);
            sum -= nums[left];
            left++;
        }
    }
    return minLen == Integer.MAX_VALUE ? 0 : minLen;
}
// 時間：O(n)，空間：O(1)

// ════════════════════════════════
// 題目 3：找所有字母異位詞
// 輸入：s = "cbaebabacd", p = "abc"
// 輸出：[0, 6]（s[0..2]="cba", s[6..8]="bac" 是 p 的異位詞）
// ════════════════════════════════
public List<Integer> findAnagrams(String s, String p) {
    List<Integer> result = new ArrayList<>();
    if (s.length() < p.length()) return result;

    int[] pCount = new int[26];
    int[] wCount = new int[26];

    // 初始化 p 的字符統計 和 第一個視窗
    for (int i = 0; i < p.length(); i++) {
        pCount[p.charAt(i) - 'a']++;
        wCount[s.charAt(i) - 'a']++;
    }

    if (Arrays.equals(pCount, wCount)) result.add(0);

    // 滑動視窗
    for (int right = p.length(); right < s.length(); right++) {
        wCount[s.charAt(right) - 'a']++;                    // 加入右邊
        wCount[s.charAt(right - p.length()) - 'a']--;       // 移出左邊
        if (Arrays.equals(pCount, wCount)) {
            result.add(right - p.length() + 1);
        }
    }
    return result;
}
```
