# 鏈表

## 反轉鏈表

```java
// 鏈表節點定義
public class ListNode {
    int val;
    ListNode next;
    ListNode(int val) { this.val = val; }
}

// ════════════════════════════════
// 題目 1：反轉整個鏈表（迭代法）
// 輸入：1→2→3→4→5
// 輸出：5→4→3→2→1
// ════════════════════════════════
public ListNode reverseList(ListNode head) {
    ListNode prev = null;
    ListNode curr = head;

    while (curr != null) {
        ListNode next = curr.next; // 暫存下一個節點
        curr.next = prev;          // 反轉指向
        prev = curr;               // prev 前進
        curr = next;               // curr 前進
    }
    return prev; // prev 最終指向新的頭節點
}
// 時間：O(n)，空間：O(1)

// 遞迴法（理解遞迴思維）
public ListNode reverseListRecursive(ListNode head) {
    // 基礎情況：空或只有一個節點
    if (head == null || head.next == null) return head;

    // 遞迴反轉後半部分
    ListNode newHead = reverseListRecursive(head.next);

    // 讓下一個節點指回自己
    head.next.next = head;
    head.next = null;

    return newHead;
}

// ════════════════════════════════
// 題目 2：反轉鏈表的前 N 個節點
// ════════════════════════════════
private ListNode successor = null; // 記錄後繼節點

public ListNode reverseN(ListNode head, int n) {
    if (n == 1) {
        successor = head.next; // 記錄第 n+1 個節點
        return head;
    }
    ListNode newHead = reverseN(head.next, n - 1);
    head.next.next = head;
    head.next = successor; // 連接後繼節點
    return newHead;
}

// ════════════════════════════════
// 題目 3：反轉鏈表區間 [left, right]
// 輸入：1→2→3→4→5，left=2，right=4
// 輸出：1→4→3→2→5
// ════════════════════════════════
public ListNode reverseBetween(ListNode head, int left, int right) {
    // 建立虛擬頭節點，簡化邊界處理
    ListNode dummy = new ListNode(-1);
    dummy.next = head;
    ListNode pre = dummy;

    // pre 移動到 left 的前一個位置
    for (int i = 0; i < left - 1; i++) {
        pre = pre.next;
    }

    ListNode curr = pre.next;
    // 執行 right - left 次「頭插法」
    for (int i = 0; i < right - left; i++) {
        ListNode next = curr.next;
        curr.next     = next.next;
        next.next     = pre.next;
        pre.next      = next;
    }
    return dummy.next;
}
```

## 環檢測（Floyd 龜兔賽跑）

```java
// ════════════════════════════════
// 題目 1：判斷鏈表是否有環
// ════════════════════════════════
public boolean hasCycle(ListNode head) {
    ListNode slow = head;
    ListNode fast = head;

    while (fast != null && fast.next != null) {
        slow = slow.next;        // 慢指針每次走 1 步
        fast = fast.next.next;   // 快指針每次走 2 步

        if (slow == fast) return true; // 相遇 → 有環
    }
    return false; // fast 到達終點 → 無環
}
// 時間：O(n)，空間：O(1)

// ════════════════════════════════
// 題目 2：找環的入口節點
// ════════════════════════════════
public ListNode detectCycle(ListNode head) {
    ListNode slow = head;
    ListNode fast = head;

    // 第一步：找到相遇點
    while (fast != null && fast.next != null) {
        slow = slow.next;
        fast = fast.next.next;
        if (slow == fast) break;
    }

    // 無環
    if (fast == null || fast.next == null) return null;

    // 第二步：一個指針從頭出發，一個從相遇點出發
    // 兩者步速相同，再次相遇處就是環的入口
    // 數學原理：head 到入口的距離 = 相遇點到入口的距離
    slow = head;
    while (slow != fast) {
        slow = slow.next;
        fast = fast.next;
    }
    return slow;
}
```

## 合併鏈表

```java
// ════════════════════════════════
// 題目 1：合併兩個有序鏈表
// 輸入：1→2→4, 1→3→4
// 輸出：1→1→2→3→4→4
// ════════════════════════════════
public ListNode mergeTwoLists(ListNode l1, ListNode l2) {
    ListNode dummy = new ListNode(-1); // 虛擬頭節點
    ListNode curr  = dummy;

    while (l1 != null && l2 != null) {
        if (l1.val <= l2.val) {
            curr.next = l1;
            l1 = l1.next;
        } else {
            curr.next = l2;
            l2 = l2.next;
        }
        curr = curr.next;
    }

    // 接上剩餘部分
    curr.next = (l1 != null) ? l1 : l2;
    return dummy.next;
}
// 時間：O(m+n)，空間：O(1)

// ════════════════════════════════
// 題目 2：找鏈表中間節點（快慢指針）
// 輸入：1→2→3→4→5
// 輸出：3（中間節點）
// ════════════════════════════════
public ListNode middleNode(ListNode head) {
    ListNode slow = head;
    ListNode fast = head;

    while (fast != null && fast.next != null) {
        slow = slow.next;
        fast = fast.next.next;
    }
    // fast 到達末尾時，slow 剛好在中間
    return slow;
}

// ════════════════════════════════
// 題目 3：刪除鏈表倒數第 N 個節點
// 輸入：1→2→3→4→5，n=2
// 輸出：1→2→3→5
// ════════════════════════════════
public ListNode removeNthFromEnd(ListNode head, int n) {
    ListNode dummy = new ListNode(-1);
    dummy.next = head;
    ListNode fast = dummy;
    ListNode slow = dummy;

    // fast 先走 n+1 步
    for (int i = 0; i <= n; i++) {
        fast = fast.next;
    }

    // fast 和 slow 同步走，直到 fast 到達末尾
    while (fast != null) {
        fast = fast.next;
        slow = slow.next;
    }

    // slow 的下一個就是要刪除的節點
    slow.next = slow.next.next;
    return dummy.next;
}
```
