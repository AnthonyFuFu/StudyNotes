# HashMap 應用題

```java
// ════════════════════════════════
// 題目 1：兩數之和（未排序版本）
// 輸入：nums = [2,7,11,15], target = 9
// 輸出：[0,1]
// ════════════════════════════════
public int[] twoSum(int[] nums, int target) {
    // key = 數值, value = 索引
    Map<Integer, Integer> map = new HashMap<>();

    for (int i = 0; i < nums.length; i++) {
        int complement = target - nums[i];

        if (map.containsKey(complement)) {
            return new int[]{map.get(complement), i};
        }
        map.put(nums[i], i);
    }
    return new int[]{};
}
// 時間：O(n)，空間：O(n)

// ════════════════════════════════
// 題目 2：字母異位詞分組
// 輸入：["eat","tea","tan","ate","nat","bat"]
// 輸出：[["bat"],["nat","tan"],["ate","eat","tea"]]
// ════════════════════════════════
public List<List<String>> groupAnagrams(String[] strs) {
    // key = 排序後的字串（異位詞排序後相同）
    Map<String, List<String>> map = new HashMap<>();

    for (String str : strs) {
        char[] chars = str.toCharArray();
        Arrays.sort(chars);
        String key = new String(chars);

        map.computeIfAbsent(key, k -> new ArrayList<>()).add(str);
    }
    return new ArrayList<>(map.values());
}
// 時間：O(n × k log k)（k = 最長字串長度）

// ════════════════════════════════
// 題目 3：和為 K 的子陣列（前綴和 + HashMap）
// 輸入：nums = [1,1,1], k = 2
// 輸出：2（共 2 個子陣列和為 2）
// ════════════════════════════════
public int subarraySum(int[] nums, int k) {
    // prefixSumCount[sum] = 前綴和為 sum 的次數
    Map<Integer, Integer> prefixSumCount = new HashMap<>();
    prefixSumCount.put(0, 1); // 前綴和為 0 出現 1 次（空子陣列）

    int count = 0, prefixSum = 0;

    for (int num : nums) {
        prefixSum += num;

        // 如果存在 prefixSum - k 的前綴和
        // 說明從那個位置到當前位置的子陣列和為 k
        count += prefixSumCount.getOrDefault(prefixSum - k, 0);

        prefixSumCount.put(prefixSum,
            prefixSumCount.getOrDefault(prefixSum, 0) + 1);
    }
    return count;
}
// 時間：O(n)，空間：O(n)

// ════════════════════════════════
// 題目 4：LRU 緩存（LinkedHashMap 實作）
// ════════════════════════════════
class LRUCache extends LinkedHashMap<Integer, Integer> {
    private final int capacity;

    public LRUCache(int capacity) {
        // accessOrder = true：按訪問順序排序（最近訪問的在最後）
        super(capacity, 0.75f, true);
        this.capacity = capacity;
    }

    public int get(int key) {
        return super.getOrDefault(key, -1);
    }

    public void put(int key, int value) {
        super.put(key, value);
    }

    @Override
    protected boolean removeEldestEntry(Map.Entry<Integer, Integer> eldest) {
        // 當 size > capacity 時，移除最久未使用的 entry（最前面的）
        return size() > capacity;
    }
}

// 手動實作 LRU（雙向鏈表 + HashMap，面試版）
class LRUCacheManual {
    private final int capacity;
    private final Map<Integer, Node> map = new HashMap<>();

    // 虛擬頭尾節點（簡化邊界處理）
    private final Node head = new Node(0, 0);
    private final Node tail = new Node(0, 0);

    private static class Node {
        int key, val;
        Node prev, next;
        Node(int key, int val) { this.key = key; this.val = val; }
    }

    public LRUCacheManual(int capacity) {
        this.capacity = capacity;
        head.next = tail;
        tail.prev = head;
    }

    public int get(int key) {
        if (!map.containsKey(key)) return -1;
        Node node = map.get(key);
        moveToHead(node); // 訪問後移到頭部（最近使用）
        return node.val;
    }

    public void put(int key, int value) {
        if (map.containsKey(key)) {
            Node node = map.get(key);
            node.val = value;
            moveToHead(node);
        } else {
            Node newNode = new Node(key, value);
            map.put(key, newNode);
            addToHead(newNode);

            if (map.size() > capacity) {
                Node removed = removeTail(); // 移除最久未使用的
                map.remove(removed.key);
            }
        }
    }

    private void addToHead(Node node) {
        node.prev = head;
        node.next = head.next;
        head.next.prev = node;
        head.next = node;
    }

    private void removeNode(Node node) {
        node.prev.next = node.next;
        node.next.prev = node.prev;
    }

    private void moveToHead(Node node) {
        removeNode(node);
        addToHead(node);
    }

    private Node removeTail() {
        Node node = tail.prev;
        removeNode(node);
        return node;
    }
}
```
