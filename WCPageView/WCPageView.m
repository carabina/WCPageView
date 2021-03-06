
#import "WCPageView.h"

NSInteger const InfiniteNumberOfItems = 1000;

@interface WCPageView () <UICollectionViewDataSource>

@end

@implementation WCPageView

#pragma mark - Getter & Setter

- (void)setDelegate:(id<UICollectionViewDelegate>)delegate {
    _collectionView.delegate = delegate;
}

- (id<UICollectionViewDelegate>)delegate {
    return _collectionView.delegate;
}

- (CGFloat)collectionViewWidth {
    return _collectionView.frame.size.width;
}

- (NSInteger)pageCount {
    return [self.dataSource numberOfItemsInPageView:self];
}

- (UICollectionViewCell *)currentDisplayingCell {
    NSArray *cells = [self.collectionView visibleCells];
    return cells.count > 0 ? cells.firstObject : nil;
}

#pragma mark Init & Deinit

+ (WCPageView *)pageViewWithFrame:(CGRect)frame dataSource:(id<WCPageViewDataSource>)dataSource {
    return [[WCPageView alloc] initWithFrame:frame dataSource:dataSource];
}

- (instancetype)initWithFrame:(CGRect)frame dataSource:(id<WCPageViewDataSource>)dataSource {
    self = [super initWithFrame:frame];
    if (self) {
        
        _animated  = YES;
        
        _infinite                            = YES;
        _automaticallyPageControlCurrentPage = YES;
        _dataSource                          = dataSource;
        _pageIndexChangePosition             = WCPageViewCurrentPageIndexChangePositionMiddle;
        CGSize _frameSize                    = frame.size;
        
        //  Set collectionViewLayout
        _layout                         = [UICollectionViewFlowLayout new];
        _layout.scrollDirection         = UICollectionViewScrollDirectionHorizontal;
        _layout.minimumInteritemSpacing = 0;
        _layout.minimumLineSpacing      = 0;
        _layout.itemSize                = frame.size;
        
        //  Set collectionView
        _collectionView = [[UICollectionView alloc]initWithFrame:CGRectMake(0, 0, _frameSize.width, _frameSize.height) collectionViewLayout:_layout];
        _collectionView.dataSource = self;
        _collectionView.pagingEnabled = true;
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.showsVerticalScrollIndicator = NO;
        _collectionView.directionalLockEnabled = YES;
        _collectionView.backgroundColor = [UIColor clearColor];
        Class cellClass = [_dataSource collectionViewCellClassOfPageView:self];
        [_collectionView registerClass:cellClass forCellWithReuseIdentifier:NSStringFromClass(cellClass)];
        [self addSubview:_collectionView];
        
        //  Set pageControl
        _pageControl = [[UIPageControl alloc]init];
        _pageControl.frame = CGRectMake(0, frame.size.height - 30, frame.size.width, 30);
        _pageControl.numberOfPages = [self.dataSource numberOfItemsInPageView:self];
        [_pageControl addTarget:self action:@selector(pageControlValueChanged) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_pageControl];
        
        //  Observer contentSize to change pageControl value
        [_collectionView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self forKeyPath:@"currentPageIndex" options:NSKeyValueObservingOptionNew context:nil];
        
        self.frequency = 5;
        [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)dealloc {
    [_collectionView removeObserver:self forKeyPath:@"contentOffset"];
    [self removeObserver:self forKeyPath:@"currentPageIndex"];
    [_timer invalidate];
}

#pragma mark - Private Methods

- (void)pageControlValueChanged {
    
}

#pragma mark - Public Methods

- (void)setPageIndex:(NSInteger)index animated:(BOOL)animated {
    if (index == self.currentPageIndex) {
        return;
    }
    CGPoint _point = self.collectionView.contentOffset;
    _point.x += (index - self.currentPageIndex) * self.collectionView.frame.size.width;
    [self.collectionView setContentOffset:_point animated:animated];
}

- (void)reloadData {
    if ([self.dataSource respondsToSelector:@selector(pageViewWillReloadData:)]) {
        [self.dataSource pageViewWillReloadData:self];
    }
    [self.collectionView reloadData];
    _pageControl.numberOfPages = [self.dataSource numberOfItemsInPageView:self];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    
    if ([keyPath isEqualToString:@"contentOffset"]) {
        NSInteger _judgedPageIndex = [self judgePageIndex];
        if (_judgedPageIndex != self.currentPageIndex) {
            self.currentPageIndex = _judgedPageIndex;
        }
    }
    
    if ([keyPath isEqualToString:@"currentPageIndex"]) {
        if (self.automaticallyPageControlCurrentPage) {
            self.pageControl.currentPage = self.currentPageIndex;
        }
        
        if ([self.dataSource respondsToSelector:@selector(pageView:currentPageIndexChangeTo:)]) {
            [self.dataSource pageView:self currentPageIndexChangeTo:self.currentPageIndex];
        }
    }
}

- (NSInteger)judgePageIndex {
    
    if (self.pageCount == 0) {
        return 0;
    }
    
    CGFloat adjustOffset = 0;
    switch (self.pageIndexChangePosition) {
        case WCPageViewCurrentPageIndexChangePositionHeader:
            adjustOffset = 0;
            break;
            
        case WCPageViewCurrentPageIndexChangePositionFooter:
            adjustOffset = -[self collectionViewWidth] / 2;
            break;
            
        case WCPageViewCurrentPageIndexChangePositionMiddle:
            adjustOffset = [self collectionViewWidth] / 2;
            break;
            
        default:
            break;
    }
    
    return (NSInteger)((_collectionView.contentOffset.x + adjustOffset)/ _collectionView.frame.size.width) % self.pageCount;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    
    if (self.pageCount == 0) {
        return 0;
    }
    
    if ([self isInfinite]) {
        return InfiniteNumberOfItems;
    }
    
    return self.pageCount;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *reuseIdentifier = NSStringFromClass([_dataSource collectionViewCellClassOfPageView:self]);
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    if ([self.dataSource respondsToSelector:@selector(pageView:configCell:atIndex:)]) {
        NSInteger index = indexPath.row % self.pageCount;
        [self.dataSource pageView:self configCell:cell atIndex:index];
    }
    
    return cell;
}

#pragma mark - Timer

- (void)timePass {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.frequency * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf showNextPage];
    });
}

- (void)setFrequency:(NSTimeInterval)frequency {
    _frequency = frequency;
    [self.timer invalidate];
    self.timer = nil;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:_frequency target:self selector:@selector(timePass) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)setTimerEnable:(BOOL)timerEnable {
    if (_timer == nil) {
        return;
    }
    if (timerEnable) {
        if (!_timer.isValid) {
            [_timer fire];
        }
    } else {
        [_timer invalidate];
    }
}

- (void)showNextPage {
    
    CGFloat _collectionViewWidth = self.collectionView.frame.size.width;
    CGFloat _oldCollectionViewOffsetX = self.collectionView.contentOffset.x;
    
    if ([self isInfinite] && (_oldCollectionViewOffsetX / _collectionViewWidth) == InfiniteNumberOfItems - 1) {
        CGFloat jumpOffsetX = ((InfiniteNumberOfItems - 1) % self.pageCount) * _collectionViewWidth;
        [self.collectionView setContentOffset:CGPointMake(jumpOffsetX, 0) animated:NO];
    }
    
    CGPoint newOffset = CGPointMake(((NSInteger)(self.collectionView.contentOffset.x / _collectionViewWidth)) * _collectionViewWidth + _collectionViewWidth, 0);
    [self.collectionView setContentOffset:newOffset animated:self.animated];
}
                  

@end
