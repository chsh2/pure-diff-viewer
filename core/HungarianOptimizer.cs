using Godot;
using System;
using Google.OrTools.Graph;

public partial class HungarianOptimizer : RefCounted
{
    private LinearSumAssignment _assignment = null!;
    private bool _solved = false;
    private LinearSumAssignment.Status _status = default;


    public void Init()
    {
        _assignment = new LinearSumAssignment();
        _solved = false;
    }

    public int AddArcWithCost(int leftNode, int rightNode, long cost)
    {
        return _assignment.AddArcWithCost(leftNode, rightNode, cost);
    }

    public int Solve()
    {
        _status = _assignment.Solve();
        _solved = true;
        return (int)_status;
    }

    public int RightMate(int leftNode)
    {
        if (!_solved)
            throw new InvalidOperationException("Solve() must be called before RightMate().");
        return _assignment.RightMate(leftNode);
    }

    public long OptimalCost()
    {
        if (!_solved)
            throw new InvalidOperationException("Solve() must be called before OptimalCost().");
        return _assignment.OptimalCost();
    }

    public int Status
    {
        get => _solved ? (int)_status : 0;
    }

    public void FreeSolver()
    {
        _assignment?.Dispose();
        _assignment = null;
    }
}
