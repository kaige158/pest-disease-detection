package com.laos.agri.dto;

import java.util.List;

/**
 * 分页数据封装
 */
public class PageData<T> {

    private List<T> items;
    private long total;
    private int page;
    private int pageSize;

    public PageData(List<T> items, long total, int page, int pageSize) {
        this.items = items;
        this.total = total;
        this.page = page;
        this.pageSize = pageSize;
    }

    public List<T> getItems() { return items; }
    public long getTotal() { return total; }
    public int getPage() { return page; }
    public int getPageSize() { return pageSize; }
}
