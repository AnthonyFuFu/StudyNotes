# 二元樹

## DFS（深度優先搜尋）

```java
// 樹節點定義
public class TreeNode {
    int val;
    TreeNode left, right;
    TreeNode(int val) { this.val = val; }
}

// ════════════════════════════════
// 前序遍歷：根 → 左 → 右
// ════════════════════════════════
public List<Integer> preorderTraversal(TreeNode root) {
    List<Integer> result = new ArrayList<>();
    preorder(root, result);
    return result;
}

private void preorder(TreeNode node, List<Integer> result) {
    if (node == null) return;
    result.add(node.val);          // 根
    preorder(node.left,  result);  // 左
    preorder(node.right, result);  // 右
}

// ════════════════════════════════
// 中序遍歷：左 → 根 → 右（BST 的中序 = 升序！）
// ════════════════════════════════
private void inorder(TreeNode node, List<Integer> result) {
    if (node == null) return;
    inorder(node.left,  result);   // 左
    result.add(node.val);          // 根
    inorder(node.right, result);   // 右
}

// ════════════════════════════════
// 後序遍歷：左 → 右 → 根
// ════════════════════════════════
private void postorder(TreeNode node, List<Integer> result) {
    if (node == null) return;
    postorder(node.left,  result); // 左
    postorder(node.right, result); // 右
    result.add(node.val);          // 根
}

// ════════════════════════════════
// 題目 1：二元樹的最大深度
// ════════════════════════════════
public int maxDepth(TreeNode root) {
    if (root == null) return 0;

    int leftDepth  = maxDepth(root.left);
    int rightDepth = maxDepth(root.right);

    return Math.max(leftDepth, rightDepth) + 1;
}
// 時間：O(n)，空間：O(h)（h = 樹高）

// ════════════════════════════════
// 題目 2：判斷是否為對稱二元樹
// ════════════════════════════════
public boolean isSymmetric(TreeNode root) {
    return isMirror(root.left, root.right);
}

private boolean isMirror(TreeNode left, TreeNode right) {
    if (left == null && right == null) return true;
    if (left == null || right == null) return false;

    return left.val == right.val
        && isMirror(left.left,  right.right)
        && isMirror(left.right, right.left);
}

// ════════════════════════════════
// 題目 3：路徑總和（是否存在根到葉子的路徑，其和等於 target）
// ════════════════════════════════
public boolean hasPathSum(TreeNode root, int targetSum) {
    if (root == null) return false;

    // 到達葉子節點，判斷剩餘值是否等於葉子節點值
    if (root.left == null && root.right == null) {
        return targetSum == root.val;
    }

    return hasPathSum(root.left,  targetSum - root.val)
        || hasPathSum(root.right, targetSum - root.val);
}

// ════════════════════════════════
// 題目 4：二元樹的最低公共祖先（LCA）
// ════════════════════════════════
public TreeNode lowestCommonAncestor(TreeNode root, TreeNode p, TreeNode q) {
    // 基礎情況：空節點 或 找到 p 或 q
    if (root == null || root == p || root == q) return root;

    // 在左右子樹中分別尋找
    TreeNode left  = lowestCommonAncestor(root.left,  p, q);
    TreeNode right = lowestCommonAncestor(root.right, p, q);

    // 左右都找到 → 當前節點就是 LCA
    if (left != null && right != null) return root;

    // 只有一側找到 → 返回那一側
    return left != null ? left : right;
}
```

## BFS（廣度優先搜尋 / 層序遍歷）

```java
// ════════════════════════════════
// 題目 1：二元樹的層序遍歷
// 輸入：    3
//          / \
//         9  20
//            / \
//           15   7
// 輸出：[[3],[9,20],[15,7]]
// ════════════════════════════════
public List<List<Integer>> levelOrder(TreeNode root) {
    List<List<Integer>> result = new ArrayList<>();
    if (root == null) return result;

    Queue<TreeNode> queue = new LinkedList<>();
    queue.offer(root);

    while (!queue.isEmpty()) {
        int  levelSize = queue.size(); // 當前層的節點數
        List<Integer> level = new ArrayList<>();

        for (int i = 0; i < levelSize; i++) {
            TreeNode node = queue.poll();
            level.add(node.val);

            if (node.left  != null) queue.offer(node.left);
            if (node.right != null) queue.offer(node.right);
        }
        result.add(level);
    }
    return result;
}
// 時間：O(n)，空間：O(n)

// ════════════════════════════════
// 題目 2：二元樹的右視圖
// 輸出每層最右邊的節點
// 輸出：[3, 20, 7]
// ════════════════════════════════
public List<Integer> rightSideView(TreeNode root) {
    List<Integer> result = new ArrayList<>();
    if (root == null) return result;

    Queue<TreeNode> queue = new LinkedList<>();
    queue.offer(root);

    while (!queue.isEmpty()) {
        int levelSize = queue.size();
        for (int i = 0; i < levelSize; i++) {
            TreeNode node = queue.poll();
            // 每層最後一個節點加入結果
            if (i == levelSize - 1) result.add(node.val);
            if (node.left  != null) queue.offer(node.left);
            if (node.right != null) queue.offer(node.right);
        }
    }
    return result;
}
```
