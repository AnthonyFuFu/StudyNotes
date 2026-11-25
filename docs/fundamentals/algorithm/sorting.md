# 排序演算法

## 快速排序（QuickSort）

```java
// 平均 O(n log n)，最壞 O(n²)（已排序時）
// 原地排序，空間 O(log n)（遞迴棧）
// 不穩定排序

public void quickSort(int[] nums, int left, int right) {
    if (left >= right) return;

    int pivotIndex = partition(nums, left, right);
    quickSort(nums, left,          pivotIndex - 1);
    quickSort(nums, pivotIndex + 1, right);
}

private int partition(int[] nums, int left, int right) {
    // 隨機選基準值（避免最壞情況）
    int randomIndex = left + (int)(Math.random() * (right - left + 1));
    swap(nums, randomIndex, right);

    int pivot = nums[right];
    int i     = left - 1; // i 指向小於 pivot 的區域末尾

    for (int j = left; j < right; j++) {
        if (nums[j] <= pivot) {
            i++;
            swap(nums, i, j);
        }
    }
    swap(nums, i + 1, right); // 把 pivot 放到正確位置
    return i + 1;
}

private void swap(int[] nums, int i, int j) {
    int temp = nums[i];
    nums[i]  = nums[j];
    nums[j]  = temp;
}

// 使用
int[] nums = {3, 6, 8, 10, 1, 2, 1};
quickSort(nums, 0, nums.length - 1);
// 結果：[1, 1, 2, 3, 6, 8, 10]
```

## 合併排序（MergeSort）

```java
// 穩定 O(n log n)，空間 O(n)
// 適合鏈表排序、外部排序（數據量超過記憶體）

public void mergeSort(int[] nums, int left, int right) {
    if (left >= right) return;

    int mid = left + (right - left) / 2; // 避免溢出
    mergeSort(nums, left,    mid);
    mergeSort(nums, mid + 1, right);
    merge(nums, left, mid, right);
}

private void merge(int[] nums, int left, int mid, int right) {
    // 複製到臨時陣列
    int[] temp = Arrays.copyOfRange(nums, left, right + 1);

    int i = 0;                    // 左半部分指針
    int j = mid - left + 1;      // 右半部分指針
    int k = left;                 // 原陣列指針

    while (i <= mid - left && j <= right - left) {
        if (temp[i] <= temp[j]) {
            nums[k++] = temp[i++];
        } else {
            nums[k++] = temp[j++];
        }
    }

    while (i <= mid - left)  nums[k++] = temp[i++];
    while (j <= right - left) nums[k++] = temp[j++];
}
```

## 排序演算法對比

```
演算法        時間複雜度（平均）  時間複雜度（最壞）  空間      穩定
─────────────────────────────────────────────────────────────────
氣泡排序      O(n²)             O(n²)             O(1)      ✅
選擇排序      O(n²)             O(n²)             O(1)      ❌
插入排序      O(n²)             O(n²)             O(1)      ✅
快速排序      O(n log n)        O(n²)             O(log n)  ❌
合併排序      O(n log n)        O(n log n)        O(n)      ✅
堆積排序      O(n log n)        O(n log n)        O(1)      ❌
計數排序      O(n + k)          O(n + k)          O(k)      ✅

Java Arrays.sort()：
  基本型別 → 雙軸快速排序（DualPivotQuicksort）
  物件型別 → TimSort（合併排序 + 插入排序的混合）
```
