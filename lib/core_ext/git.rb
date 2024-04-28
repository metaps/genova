module Git
  class Base
    def remote_show_origin
      lib.remote_show_origin
    end

    def submodule_update(latest_submodule)
      lib.submodule_update(latest_submodule)
    end
  end

  class Lib
    def branches_all
      arr = []
      count = 0

      command_lines('branch', '-a', '--sort=-authordate').each do |b|
        current = (b[0, 2] == '* ')
        arr << [b.gsub('* ', '').strip, current]
        count += 1

        break if count == Settings.slack.interactive.branch_limit
      end
      arr
    end

    def tags
      arr = []
      count = 0

      command_lines('tag', '--sort=-v:refname').each do |t|
        arr << t
        count += 1

        break if count == Settings.slack.interactive.tag_limit
      end
      arr
    end

    def submodule_update(latest_submodule)
      command('-C', @git_work_dir, 'submodule', 'update', '--init')

      if latest_submodule
        command('-C', @git_work_dir, 'submodule', 'update', '--remote')
      else
        command('-C', @git_work_dir, 'submodule', 'update')
      end
    end

    def remote_show_origin
      command('remote', 'show', 'origin')
    end
  end
end
