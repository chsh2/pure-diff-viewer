using Godot;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using LibGit2Sharp;

public partial class GitUtils : RefCounted
{
    public static bool IsGitRepository(string repoPath)
    {
        return Repository.IsValid(repoPath);
    }

    public static string[] GetBranches(string repoPath)
    {
        using var repo = new Repository(repoPath);
        return [.. repo.Branches.Select(b => b.FriendlyName)];
    }

    public static string[] GetTags(string repoPath)
    {
        using var repo = new Repository(repoPath);
        return [.. repo.Tags.Select(t => t.FriendlyName)];
    }

    public static string GetHeadBranch(string repoPath)
    {
        using var repo = new Repository(repoPath);
        var headRef = repo.Refs["HEAD"];
        string branchName;
        string commitSha = repo.Head.Tip.Sha;

        if (headRef.TargetIdentifier.StartsWith("refs/heads/"))
        {
            branchName = headRef.TargetIdentifier["refs/heads/".Length..];
        }
        else
        {
            branchName = commitSha;
        }

        return branchName;
    }

    public static string GetHeadSha(string repoPath)
    {
        using var repo = new Repository(repoPath);
        return repo.Head.Tip.Sha;
    }

    public static string[] GetCommitNames(string repoPath, string branchName, int maxCount = 0)
    {
        using var repo = new Repository(repoPath);

        var branch = repo.Branches.FirstOrDefault(b => b.FriendlyName == branchName);
        if (branch == null)
            return [];

        var commits = repo.Commits
            .QueryBy(new CommitFilter
            {
                SortBy = CommitSortStrategies.Topological | CommitSortStrategies.Time,
                IncludeReachableFrom = branch
            });

        if (maxCount > 0) {
            commits = (ICommitLog)commits.Take(maxCount);
        }

        return [.. commits.Select(c => c.Sha[..Math.Min(7, c.Sha.Length)])];
    }

    public static string[] GetCommitShas(string repoPath, string branchName, int maxCount = 0)
    {
        using var repo = new Repository(repoPath);

        var branch = repo.Branches.FirstOrDefault(b => b.FriendlyName == branchName);
        if (branch == null)
            return [];

        var commits = repo.Commits
            .QueryBy(new CommitFilter
            {
                SortBy = CommitSortStrategies.Topological | CommitSortStrategies.Time,
                IncludeReachableFrom = branch
            });

        if (maxCount > 0) {
            commits = (ICommitLog)commits.Take(maxCount);
        }

        return [.. commits.Select(c => c.Sha)];
    }

    public static string[] GetCommitMessages(string repoPath, string branchName, int maxCount = 0)
    {
        using var repo = new Repository(repoPath);

        var branch = repo.Branches.FirstOrDefault(b => b.FriendlyName == branchName);
        if (branch == null)
            return [];

        var commits = repo.Commits
            .QueryBy(new CommitFilter
            {
                SortBy = CommitSortStrategies.Topological | CommitSortStrategies.Time,
                IncludeReachableFrom = branch
            });

        if (maxCount > 0) {
            commits = (ICommitLog)commits.Take(maxCount);
        }

        return [.. commits.Select(c => c.MessageShort)];
    }

    public static string[] GetCommitAuthors(string repoPath, string branchName, int maxCount = 0)
    {
        using var repo = new Repository(repoPath);

        var branch = repo.Branches.FirstOrDefault(b => b.FriendlyName == branchName);
        if (branch == null)
            return [];

        var commits = repo.Commits
            .QueryBy(new CommitFilter
            {
                SortBy = CommitSortStrategies.Topological | CommitSortStrategies.Time,
                IncludeReachableFrom = branch
            });

        if (maxCount > 0) {
            commits = (ICommitLog)commits.Take(maxCount);
        }

        return [.. commits.Select(c => c.Author.Name)];
    }

    public static string[] GetCommitDates(string repoPath, string branchName, int maxCount = 0)
    {
        using var repo = new Repository(repoPath);

        var branch = repo.Branches.FirstOrDefault(b => b.FriendlyName == branchName);
        if (branch == null)
            return [];

        var commits = repo.Commits
            .QueryBy(new CommitFilter
            {
                SortBy = CommitSortStrategies.Topological | CommitSortStrategies.Time,
                IncludeReachableFrom = branch
            });

        if (maxCount > 0) {
            commits = (ICommitLog)commits.Take(maxCount);
        }

        return [.. commits.Select(c => c.Author.When.ToString("yyyy-MM-dd HH:mm:ss zzz"))];
    }

    public static string[] GetCommitFilePaths(string repoPath, string commitId)
    {
        return [.. GetTreeChanges(repoPath, commitId).Select(change => change.Path)];
    }

    public static string[] GetCommitFileKinds(string repoPath, string commitId)
    {
        return [.. GetTreeChanges(repoPath, commitId).Select(change => change.Status.ToString())];
    }

    private static TreeChanges GetTreeChanges(string repoPath, string commitId)
    {
        using var repo = new Repository(repoPath);
        var commit = repo.Lookup<Commit>(commitId) ?? throw new ArgumentException("Invalid commit ID");
        var oldTree = commit.Parents.FirstOrDefault()?.Tree;
        var newTree = commit.Tree;

        return repo.Diff.Compare<TreeChanges>(oldTree, newTree);
    }

    public static string GetFileContent(string repoPath, string commitId, string filePath)
    {
        using var repo = new Repository(repoPath);
        var commit = repo.Lookup<Commit>(commitId) ?? throw new ArgumentException($"Commit {commitId} not found.");
        
        if (commit[filePath] == null) return string.Empty;
        var entry = commit[filePath];

        var blob = entry.Target as Blob ?? throw new InvalidOperationException($"Path {filePath} is not a file.");

        using var reader = new StreamReader(blob.GetContentStream(), System.Text.Encoding.UTF8);
        return reader.ReadToEnd();
    }

    public static string[] GetLatestFilesPaths(string repoPath)
    {
        return [.. GetStatusEntries(repoPath).Select(entry => entry.FilePath)];
    }

    public static string[] GetLatestFilesKinds(string repoPath)
    {
        return [.. GetStatusEntries(repoPath).Select(entry => ToChangeKind(entry.State).ToString())];
    }

    private static ChangeKind ToChangeKind(FileStatus status)
    {
        if (status.HasFlag(FileStatus.NewInWorkdir) || status.HasFlag(FileStatus.NewInIndex))
            return ChangeKind.Added;

        if (status.HasFlag(FileStatus.DeletedFromWorkdir) || status.HasFlag(FileStatus.DeletedFromIndex))
            return ChangeKind.Deleted;

        if (status.HasFlag(FileStatus.ModifiedInWorkdir) || status.HasFlag(FileStatus.ModifiedInIndex))
            return ChangeKind.Modified;

        return ChangeKind.Unmodified;
    }

    private static List<StatusEntry> GetStatusEntries(string repoPath)
    {
        using var repo = new Repository(repoPath);
        var options = new StatusOptions
        {
            IncludeUnaltered = true,
            IncludeUntracked = true,
            IncludeIgnored = false,
            RecurseUntrackedDirs = true,
        };

        return [.. repo.RetrieveStatus(options)];
    }

    public static string[] GetDiffBetweenCommits(string repoPath, string commitIdA, string commitIdB)
    {
        using var repo = new Repository(repoPath);
        var commitA = repo.Lookup<Commit>(commitIdA);
        var commitB = repo.Lookup<Commit>(commitIdB);

        if (commitA == null || commitB == null)
            return [];

        var changes = repo.Diff.Compare<TreeChanges>(commitA.Tree, commitB.Tree);
        var changedFiles = changes
            .Where(t => t.Status != ChangeKind.Unmodified)
            .Select(t => t.Path)
            .Distinct()
            .ToArray();

        return changedFiles;
    }

    public static string GetFileDiff(string repoPath, string commitIdA, string commitIdB, string filePath)
    {
        using var repo = new Repository(repoPath);
        var commitA = repo.Lookup<Commit>(commitIdA);
        var commitB = repo.Lookup<Commit>(commitIdB);

        if (commitA == null || commitB == null)
            return string.Empty;

        var patch = repo.Diff.Compare<Patch>(commitA.Tree, commitB.Tree);
        var diff = patch[filePath];
        return diff?.ToString() ?? string.Empty;
    }

  // Method of the library QueryBy(filePath, filter) is slow. Use a workaround instead.
  public static string[] GetCommitsForFile(string repoPath, string branchName, string filePath, int maxCount = 0, int maxCommitCount = 0)
    {
        using var repo = new Repository(repoPath);

        var branch = repo.Branches.FirstOrDefault(b => b.FriendlyName == branchName);
        if (branch == null)
            return [];

        var result = new List<string>();
        int checkedCount = 0;

        var filter = new CommitFilter
        {
            SortBy = CommitSortStrategies.Topological | CommitSortStrategies.Time,
            IncludeReachableFrom = branch
        };

        foreach (var commit in repo.Commits.QueryBy(filter))
        {
            checkedCount++;

            if (maxCommitCount > 0 && checkedCount > maxCommitCount)
                break;

            bool commitHasFile = commit[filePath] != null;
            var parent = commit.Parents.FirstOrDefault();
            bool parentHasFile = parent != null && parent[filePath] != null;

            if (!commitHasFile && !parentHasFile)
                continue;

            if (parent == null)
            {
                if (commitHasFile)
                    result.Add(commit.Sha);
                continue;
            }

            var changes = repo.Diff.Compare<TreeChanges>(parent.Tree, commit.Tree);
            var fileChange = changes.FirstOrDefault(c => c.Path == filePath);

            if (fileChange != null && fileChange.Status != ChangeKind.Unmodified)
            {
                result.Add(commit.Sha);
            }

            if (maxCount > 0 && result.Count >= maxCount)
                break;
        }

        return [.. result];
    }
}
